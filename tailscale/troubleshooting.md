# Tailscale 自建 DERP 排查笔记:从自签证书到 IP 证书

这份笔记记录了一次自建 Tailscale DERP 中继的完整排查过程。核心结论是:
**第三方 Tailscale 客户端(如小火箭/Shadowrocket)不支持自签证书的 DERP 节点**,必须使用
公网可信证书。在没有域名、只有公网 IP 的情况下,可通过 Let's Encrypt 的 `shortlived` profile
申请 IP 地址证书解决。

> 适用场景:只有公网 IP、没有域名,想把一台 VPS 作为 Tailscale DERP 中继,且需要兼容第三方客户端。

## 0. 背景与现象

网络拓扑(脱敏):

```
手机(移动蜂窝, CGNAT)  ──┐
                          ├──> 自建 DERP(VPS, 公网IP)  ──> 家庭网络节点(Mac/Mac-mini)
家庭宽带(普通 NAT)    ──┘
```

现象:

- 手机上用第三方客户端(小火箭)配置 Tailscale 出口,访问 Tailscale 内网节点连不上
- 日志报错:`WireGuard packet could not be sent on magicsock path`
- 大量 `TCP conn closed (err=1)`
- **官方 Tailscale 客户端 + 同一个自建 DERP = 正常**
- **第三方客户端 + 官方 DERP = 正常**
- **第三方客户端 + 自建 DERP(自签证书) = 失败**

三条链路两条通、一条不通,问题被锁定在"第三方客户端 + 自建 DERP"这条组合上。

## 1. 根因:第三方客户端不信任自签证书

### 1.1 证据

自建 DERP 用 `derper --certmode manual --hostname <PUBLIC_IP>` 时,derper 会为该 IP 生成
自签证书。官方客户端通过 DERP map 里的 `CertName: sha256-raw:<指纹>` 做指纹绑定,可以绕过
PKI 验证直连。

但第三方客户端(小火箭)的 TLS 实现**不认指纹绑定,只走标准证书链校验**。于是握手时:

```text
# derper 服务端日志(自签证书阶段)
http: TLS handshake error from <手机出口IP>:xxxxx: remote error: tls: unknown certificate
```

`remote error: tls: unknown certificate` 是**客户端发回来的**中止信号,意思是客户端在验证
derper 证书时认为"未知/不可信",主动断开。

### 1.2 为什么官方客户端没问题

官方 Tailscale 客户端读到 DERP map 里的 `CertName: sha256-raw:...` 后,会用指纹直接比对,
不经过系统证书链。所以自签证书对官方客户端透明。

第三方客户端没有实现这套指纹机制,只能依赖标准 TLS,因此自签证书必然失败。

### 1.3 结论

**自签证书是根因。** 解决方向:给自建 DERP 换上公网可信证书。

## 2. 解决方案:Let's Encrypt IP 地址证书

### 2.1 为什么用 IP 证书

没有域名,无法走常规的域名证书。Let's Encrypt 支持为纯 IP 地址签发证书,但有一个硬限制
(见第 4 节)。

### 2.2 申请过程

前提:VPS 的 80 端口(或 webroot)可被 Let's Encrypt 访问,用于 HTTP-01 校验。

用 snap 版 certbot(版本需 ≥ 5.x,旧版 apt 版 2.9.0 不支持 IP 续期):

```bash
# 安装 snap 版 certbot(如果只有 apt 旧版)
sudo snap install --classic certbot

# 申请 IP 证书(shortlived profile 是 LE 对 IP 的唯一支持路径)
sudo certbot certonly \
  --webroot -w /var/www/html \
  --preferred-profile shortlived \
  -m admin@example.com \
  --agree-tos \
  --no-eff-email \
  --cert-name <PUBLIC_IP> \
  -n <PUBLIC_IP>          # 注意:IP 用 -n,不是 -d
```

说明:

- `--preferred-profile shortlived`:Let's Encrypt 对 IP 标识符只支持 shortlived profile
- `-n <PUBLIC_IP>`:IP 地址标识符用 `-n`(ipaddrs),不是域名的 `-d`
- `--cert-name <PUBLIC_IP>`:证书名,续期时按这个名字识别
- 校验方式用 webroot,也可用 standalone(但 standalone 会占用 80 端口)

### 2.3 部署证书到 derper

derper 的 `certmode=manual` 会从 `certdir` 读取 `<hostname>.crt` 和 `<hostname>.key`。把
Let's Encrypt 的证书复制过去:

```bash
CERT_NAME="<PUBLIC_IP>"
DERPER_CERT_DIR="/var/lib/derper/certs"

sudo install -o derper -g derper -m 0644 \
  /etc/letsencrypt/live/${CERT_NAME}/fullchain.pem \
  ${DERPER_CERT_DIR}/${CERT_NAME}.crt

sudo install -o derper -g derper -m 0600 \
  /etc/letsencrypt/live/${CERT_NAME}/privkey.pem \
  ${DERPER_CERT_DIR}/${CERT_NAME}.key

sudo systemctl restart derper
```

### 2.4 配置自动续期 deploy hook

shortlived 证书有效期只有约 6 天,续期成功后必须把新证书同步到 derper 并重启。写一个
deploy hook,certbot 续期成功后会自动调用:

```bash
sudo tee /etc/letsencrypt/renewal-hooks/deploy/10-deploy-derper-ip-cert.sh <<'EOF'
#!/bin/sh
set -eu

CERT_NAME="<PUBLIC_IP>"
DERPER_CERT_DIR="/var/lib/derper/certs"

if [ "${RENEWED_LINEAGE:-}" != "/etc/letsencrypt/live/${CERT_NAME}" ]; then
  exit 0
fi

install -o derper -g derper -m 0644 "${RENEWED_LINEAGE}/fullchain.pem" "${DERPER_CERT_DIR}/${CERT_NAME}.crt"
install -o derper -g derper -m 0600 "${RENEWED_LINEAGE}/privkey.pem" "${DERPER_CERT_DIR}/${CERT_NAME}.key"
systemctl restart derper
EOF

sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/10-deploy-derper-ip-cert.sh
```

### 2.5 续期验证

```bash
# 注意:必须用 snap 版 certbot,不要用 PATH 里的 apt 旧版
sudo /snap/bin/certbot renew --cert-name <PUBLIC_IP> --dry-run
```

成功标志:

```text
Congratulations, all simulated renewals succeeded
```

snap 版 certbot 自带 `snap.certbot.renew.timer`,默认每 12 小时跑一次 `certbot renew`,
对 6 天有效期的证书绰绰有余。

## 3. 更新 Tailscale DERP Map

换成正式证书后,DERP map 里**必须删除 `CertName` 字段**,让客户端走标准 TLS 校验。

### 3.1 修改前(自签证书,已过时)

```jsonc
"900": {
  "RegionID": 900,
  "Nodes": [{
    "Name": "900a",
    "RegionID": 900,
    "HostName": "<PUBLIC_IP>",
    "CertName": "sha256-raw:<指纹>",   // ← 删掉这行
    "DERPPort": 8443,
    "STUNPort": 3478
  }]
}
```

### 3.2 修改后(正式 IP 证书)

```jsonc
"900": {
  "RegionID": 900,
  "RegionCode": "myvps",
  "RegionName": "My VPS DERP",
  "Nodes": [{
    "Name": "900a",
    "RegionID": 900,
    "HostName": "<PUBLIC_IP>",
    "DERPPort": 8443,
    "STUNPort": 3478
  }]
}
```

### 3.3 为什么要删 CertName

`CertName: sha256-raw:...` 是自签证书的指纹绑定机制。换成公网可信证书后,必须让客户端走
标准证书链校验,留着 `CertName` 反而会让客户端尝试指纹比对(对不上)。

## 4. 关于 IP 证书有效期:6 天是硬限制

这是这次排查中容易误解的点,单独说明。

### 4.1 Let's Encrypt 的 profile 体系

Let's Encrypt 当前(2026)有三个 profile:

| Profile | 有效期 | 支持的标识符 |
|---|---|---|
| `classic`(默认) | 90 天 | **仅 DNS**(域名) |
| `tlsserver` | 45 天 | **仅 DNS**(域名) |
| `shortlived` | 约 6 天(160h) | **DNS + IP** |

关键:**只有 `shortlived` 的标识符类型包含 IP**。所以只要证书 SAN 里有 IP 地址,服务端就只能
用 shortlived profile 出证。**纯 IP 无法获得 90 天证书,这是 Let's Encrypt 的硬限制,没有例外。**

官方 FAQ 原话:"有效期无法调整,没有例外。"

### 4.2 90 天证书的唯一途径

给 IP 配一个域名(DNS A 记录指向该 IP),用 `classic` profile 申请普通域名证书,即可获得
90 天有效期。纯 IP 路径下没有 90 天选项。

### 4.3 6 天有效期对运维的影响

shortlived 证书对**续期自动化可靠性**要求高:6 天续不上就失效。好在 snap certbot 每 12
小时跑一次续期,远超 LE 对 6 天证书"每 3 天续一次"的建议频率。只要续期链路不断,6 天有效期
不是问题。

## 5. 验证:确认流量真的走自建 DERP

换好证书、更新 DERP map 后,需要确认第三方客户端确实在用自建中继,而不是回退到官方 DERP。

### 5.1 客户端侧:netcheck

```bash
tailscale netcheck
```

重点看:

- `Nearest DERP` 是否是你的自建 region
- 自建 region 延迟是否合理(国内 VPS 一般 10-30ms)
- 如果 `Nearest DERP` 是官方 region,说明自建没生效或延迟更高

### 5.2 服务端侧:derper 日志和连接

```bash
# derper 是否在跑、端口是否监听
sudo systemctl status derper
sudo ss -tnlp | grep -E ':8443|:3478'

# 看 TLS 握手是否有错误(unknown certificate = 客户端不信任)
sudo journalctl -u derper --since '10 min ago' | grep -iE 'handshake|tls|error'

# 当前连到 8443 的客户端
sudo ss -tnp | grep ':8443'
```

### 5.3 铁证:抓包确认流量经过自建中继

最可靠的验证方法是:在 VPS 上抓包,同时在客户端访问一个内网节点,看自建 derper 上对应
连接的字节计数是否同步飙升。

```bash
# 在 VPS 上,抓取客户端连接的流量
sudo tcpdump -n -i any 'port 8443' -c 50

# 或用 ss 看字节计数变化(抓取前后各看一次)
sudo ss -tnpi | grep ':8443'
```

判断标准:

- 客户端访问内网节点时,自建 derper 上对应连接的 `bytes_received` / `data_segs_in` **同步增长**
- `lastrcv`(最近收包时间)是几十毫秒级,说明持续在传数据
- 如果字节计数完全不动,说明流量走的是官方 DERP,自建没在用

### 5.4 区分"走自建"还是"回退官方"

一个常见误区:看到能访问了就以为自建生效了,实际可能回退到了官方。区分方法:

| 现象 | 含义 |
|---|---|
| netcheck 显示 Nearest DERP = 自建 region | 自建可达,但未必在用 |
| ping 节点显示 `via DERP(自建code)` | 确实走自建 |
| ping 节点显示 `via DERP(hkg/tok/...)` | 走官方,自建没在用 |
| VPS derper 上字节计数飙升 | 铁证走自建 |

**必须用抓包/字节计数确认,不能只看"能不能访问"。**

## 6. 冗余:自建 + 官方并存

### 6.1 不要屏蔽官方 DERP

DERP map 的关键字段 `OmitDefaultRegions`:

| 值 | 含义 |
|---|---|
| `false` / 不设(默认) | 官方 region 全部保留 + 自建 region 并存 |
| `true` | 只用自建,官方全部屏蔽 |

**强烈建议保持 `false`**(即不设这个字段)。这样:

- 自建正常时:客户端优先用自建(低延迟)
- 自建挂掉时:自动 failover 到官方(hkg/tok/sin 等,稍慢但能通)

如果设成 `true` 只用自建,自建一断全 tailnet 断连,失去冗余。

### 6.2 验证官方 region 是否保留

```bash
tailscale debug netmap | jq '.DERPMap | {OmitDefaultRegions, region_count: (.Regions | length)}'
```

正常应显示 20+ 个 region(官方)+ 你的自建 region。

## 7. 国内网络下的打洞 vs 中继

### 7.1 打洞成功率:分场景看

| 场景 | 打洞成功率 | 原因 |
|---|---|---|
| 同一局域网 | 100% | 不经过 NAT |
| 家庭宽带 ↔ 公网IP设备 | 高 | 公网IP端天然可打洞 |
| 家庭宽带 ↔ 家庭宽带 | 中(30-50%) | 取决于双方 NAT 类型 |
| **移动蜂窝 ↔ 家庭宽带** | **低(<20%)** | 移动 CGNAT 多为 Symmetric NAT |
| 跨运营商 | 很低 | UDP 跨网常被限速/丢弃 |

### 7.2 关键:NAT 类型决定成败

打洞靠 UDP NAT 穿透,前提是至少一端是可打洞的 NAT(Cone 类型)。Symmetric NAT 几乎和
任何类型都不兼容。国内移动蜂窝大规模 CGNAT 几乎都是 Symmetric,所以**手机访问家庭网络
这个场景,打洞基本必败,DERP 是唯一通路**。

这也是为什么花精力搞自建 DERP 是值得的:对手机这种移动设备,DERP 不是"备用",而是"主力"。
自建 DERP(国内,低延迟)vs 官方 DERP(海外,几十到上百 ms)体验差距很大。

### 7.3 可提升打洞成功率的方向(家庭端)

- **路由器开 UPnP / NAT-PMP / PCP**:让 Tailscale 能主动建立端口映射。用
  `tailscale debug portmap` 可探测路由器是否支持。三种全关时打洞成功率大打折扣。
- **确认本端不是 Symmetric NAT**:`tailscale netcheck` 里 `MappingVariesByDestIP` 为空/false
  表示是 Cone(可打洞),为 true 表示 Symmetric(难打洞)。
- **公网 IPv6**:两端都有公网 IPv6 可绕过 IPv4 NAT 直连。但若为了代理可控主动关闭了 IPv6,
  这条路不可用。

注意:以上优化的是**家庭端**。手机端 CGNAT 你改不了,所以手机场景的打洞失败无解,只能靠 DERP。

## 8. 踩坑记录

### 8.1 derper 日志的 "self-signed" 误导

`certmode=manual` 下,即使 derper 实际加载的是 Let's Encrypt 正式证书,启动日志仍会打印:

```text
Using self-signed certificate for IP address "X.X.X.X"
CertName: sha256-raw:...
```

这是 manual 模式的默认提示,**不代表实际在用自签证书**。判断真实证书要用序列号比对或外部
TLS 握手验证:

```bash
# 外部 TLS 握手(金标准)
echo | openssl s_client -connect <PUBLIC_IP>:8443 -servername <PUBLIC_IP> 2>&1 | grep 'Verify return code'
# 期望: Verify return code: 0 (ok)

# /derp/probe
curl -sS -o /dev/null -w 'HTTP %{http_code}' https://<PUBLIC_IP>:8443/derp/probe
# 期望: HTTP 200
```

### 8.2 certbot 版本陷阱

系统里可能同时有 apt 旧版(2.9.0)和 snap 新版(5.6.0)两个 certbot:

- `which certbot` 可能指向 apt 旧版
- apt 旧版 2.9.0 **不支持 IP 证书续期**,跑 dry-run 会报
  `At least one of domains or ipaddrs parameter need to be not empty`
- 真正负责续期的是 snap 版,自带 `snap.certbot.renew.timer`

排查续期问题时,务必用 `/snap/bin/certbot` 而不是 PATH 里的 `certbot`。查定时器要用:

```bash
systemctl list-timers 'snap.certbot.*' --all
# 不要只查 certbot.*,会漏掉 snap 的
```

### 8.3 shortlived 证书看起来"快过期"

`certbot certificates` 显示 IP 证书只有 6 天有效期,容易误以为是 staging 证书或配置错误。
实际上是 `preferred_profile = shortlived` 的正常结果(见第 4 节)。检查 renewal conf 确认:

```bash
sudo cat /etc/letsencrypt/renewal/<PUBLIC_IP>.conf | grep -E 'profile|server'
# server 应是 acme-v02(生产),不是 acme-staging
```

## 9. 完整验证清单

部署完成后的逐项验证:

```bash
# 1. derper 运行状态
ssh vps 'sudo systemctl status derper'

# 2. 端口监听
ssh vps 'sudo ss -tnlp | grep -E ":8443|:3478"'

# 3. 证书实际有效期和 SAN
ssh vps 'sudo openssl x509 -in /etc/letsencrypt/live/<PUBLIC_IP>/cert.pem -noout -dates -ext subjectAltName'

# 4. derper 加载的证书 = Let's Encrypt 证书(序列号比对)
ssh vps 'LE=$(sudo openssl x509 -in /etc/letsencrypt/live/<PUBLIC_IP>/cert.pem -noout -serial | cut -d= -f2); DR=$(sudo openssl x509 -in /var/lib/derper/certs/<PUBLIC_IP>.crt -noout -serial | cut -d= -f2); [ "$LE" = "$DR" ] && echo MATCH || echo MISMATCH'

# 5. 外部 TLS 验证(金标准)
echo | openssl s_client -connect <PUBLIC_IP>:8443 2>&1 | grep 'Verify return code'

# 6. /derp/probe
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' https://<PUBLIC_IP>:8443/derp/probe

# 7. 续期 dry-run(用 snap 版!)
ssh vps 'sudo /snap/bin/certbot renew --cert-name <PUBLIC_IP> --dry-run'

# 8. 续期定时器
ssh vps 'systemctl list-timers "snap.certbot.*" --all'

# 9. 客户端 netcheck
tailscale netcheck

# 10. 抓包确认走自建 DERP(访问内网节点时在 VPS 上跑)
ssh vps 'sudo ss -tnpi | grep ":8443"'
```

## 10. 参考

- Let's Encrypt Profiles(各 profile 的标识符类型与有效期):https://letsencrypt.org/docs/profiles/
- Let's Encrypt FAQ(有效期不可调整):https://letsencrypt.org/docs/faq/
- Tailscale 自定义 DERP:https://tailscale.com/s/custom-derp
- Certbot profile 参数:`--preferred-profile` / `--required-profile`,见 https://eff-certbot.readthedocs.io/en/stable/using.html
