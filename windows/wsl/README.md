# WSL2 远程访问（SSH 直连）配置

目标：从本机（macOS）通过 SSH 直接登录 Windows 11 上的 WSL2 (Ubuntu)，获得原生 Linux 开发环境，用于运行 AI 工具、编译等场景。

架构概览：

```text
macOS ──ssh:2223──> Windows 11 (WSL2 Ubuntu-26.04 sshd)
        mirrored 网络模式：WSL 与 Windows 共享 IP，无需端口转发
```

## 前提

- Windows 11（24H2 及以上，涉及 Hyper-V 防火墙与 .wslconfig 参数，低版本行为可能不同）
- WSL2 + 发行版（本次为 Ubuntu-26.04），已启用 systemd（`/etc/wsl.conf` 中 `[boot] systemd=true`）
- Windows 侧 OpenSSH Server 已运行（默认 2222 端口，与 WSL 的 2223 互不干扰）
- `.wslconfig` 使用 `networkingMode=mirrored`（WSL 共享 Windows 的 LAN IP，是"无需转发"的关键）

## 配置步骤

### 1. 确认网络模式与镜像 IP

```powershell
# Windows 侧
wsl --status
Get-Content $env:USERPROFILE\.wslconfig

# WSL 侧（eth0 应显示与 Windows 相同的局域网 IP）
wsl -d Ubuntu-26.04 -- bash -lc 'ip addr show eth0 | grep "inet "'
```

如果 eth0 是 `172.x` 私有段，说明是 NAT 模式，需在 `.wslconfig` 设置 `networkingMode=mirrored` 并 `wsl --shutdown` 重启。

### 2. WSL 内安装并配置 sshd

```bash
# 进入 WSL（root）
wsl -d Ubuntu-26.04 -u root

apt-get update && apt-get install -y openssh-server

# 备份原配置，改为独立端口（避免与 Windows sshd 冲突）
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)
sed -i -E "s/^#?Port .*/Port 2223/; s/^#?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
```

**重要**：Ubuntu 新版默认使用 socket activation（`ssh.socket`），它会与 `ssh.service` 同时监听同一端口并互相冲突，导致连接建立后几秒内被 systemd 杀掉。必须禁用 socket 激活，只保留经典模式：

```bash
systemctl disable --now ssh.socket   # 需要 root
systemctl enable --now ssh
```

### 3. Windows 防火墙放行（24H2 关键坑）

Windows 11 24H2 引入了 **Hyper-V 防火墙**，WSL 默认入站策略是 `Block`。普通 `New-NetFirewallRule` 对 WSL 流量**无效**，必须创建 Hyper-V 规则的 `VMCreatorId` 指向 WSL：

```powershell
# 管理员权限 PowerShell
New-NetFirewallHyperVRule -Name "WSL-sshd-2223" `
  -DisplayName "WSL sshd 2223 (Hyper-V)" `
  -Direction Inbound -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' `
  -Protocol TCP -LocalPorts 2223 -Action Allow
```

`{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}` 是 WSL 的固定 VMCreatorId，可用 `Get-NetFirewallHyperVVMCreator` 确认。

### 4. 部署公钥（免密登录）

```bash
# 将本机公钥写入 WSL 用户
ssh windows-11 "wsl -d Ubuntu-26.04 -u root -- bash -lc 'mkdir -p /home/<USER>/.ssh && chmod 700 /home/<USER>/.ssh && echo \"<PUBKEY>\" >> /home/<USER>/.ssh/authorized_keys && chmod 600 /home/<USER>/.ssh/authorized_keys && chown -R <USER>:<USER> /home/<USER>/.ssh'"
```

### 5. 本机 SSH config 别名

`~/.ssh/config` 增加：

```ini
# WSL (Ubuntu) on windows-11, mirrored networking shares host IP
Host wsl-11
  HostName <WINDOWS_IP>
  Port 2223
  User <USER>
  IdentityFile ~/.ssh/id_ed25519
```

### 6. WSL 常驻（防止自动关闭）

WSL 存在**两个独立的空闲计时器**，SSH 直连不计入"活动会话"，默认会把 WSL 关掉：

| 参数 | 位置 | 默认 | 作用 |
|---|---|---|---|
| `instanceIdleTimeout` | `[general]` 段 | 15 秒 | 关闭发行版实例（SSH 连接不算活动，15 秒即关） |
| `vmIdleTimeout` | `[wsl2]` 段 | 60 秒 | 关闭整个 VM |

`C:\Users\<USER>\.wslconfig`：

```ini
[general]
instanceIdleTimeout=-1

[wsl2]
vmIdleTimeout=-1
networkingMode=mirrored
autoProxy=true
firewall=true

[experimental]
hostAddressLoopback=true
```

修改后必须重启生效：

```powershell
wsl --shutdown
wsl -d Ubuntu-26.04 -u root -- bash -lc 'systemctl start ssh'
```

## 验证

```bash
# 长连接测试（3 分钟无断开即通过）
ssh wsl-11 "for i in \$(seq 1 18); do echo alive-\$i; sleep 10; done"

# 断连后确认 WSL 仍保持运行
ssh windows-11 "wsl -l -v"   # 应显示 Running，而非 Stopped
```

## 回滚

```powershell
# 删除 Hyper-V 防火墙规则
Remove-NetFirewallHyperVRule -Name "WSL-sshd-2223"

# 恢复 WSL 自动关闭（移除 -1）
# 删除 .wslconfig 中的 [general] 与 vmIdleTimeout 行，或还原备份 .wslconfig.bak.*

# 恢复 ssh.socket 激活
wsl -d Ubuntu-26.04 -u root -- systemctl enable --now ssh.socket
```

## 踩坑记录

1. **Hyper-V 防火墙拦截 WSL 入站**：24H2 起普通防火墙规则对 WSL 无效，必须用 `New-NetFirewallHyperVRule` + WSL 的 VMCreatorId。
2. **ssh.socket 与 ssh.service 双监听冲突**：连接建立 2-11 秒后被 systemd 杀掉（日志见 `journalctl -u ssh` 的 `Received signal 15`），禁用 `ssh.socket` 解决。
3. **SSH 连接不阻止 WSL 自动关闭**：WSL 只认 wsl.exe client id 算"活动"，SSH 直连不算。必须显式设置 `instanceIdleTimeout=-1`（仅设 `vmIdleTimeout` 无效）。
4. **配置不生效的假象**：改 `.wslconfig` 后必须 `wsl --shutdown` 等待数秒再启动；验证参数是否生效可用 `memory=8GB` 临时测试（查 `/proc/meminfo`），确认生效后再移除。
5. **排障路径**：先查 WSL 内 `journalctl -u ssh` / `journalctl | tail` 看关闭是 sshd 被杀还是整个 VM poweroff；再查 Windows 侧 `wsl -l -v` 判断是否实例已停止。
6. **资源**：WSL2 为动态内存 VM，上限默认为主机内存 50%（本次 31.5GB 主机 → 16GB），空闲时自动归还（实测 8GB 占用 60 秒内回到 ~1GB），常驻不占资源。
