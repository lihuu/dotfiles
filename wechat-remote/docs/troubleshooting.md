# wechat-remote 故障排查与已知问题

xpra 转发 OrbStack Ubuntu VM 里的 Linux 微信到 macOS 桌面。本文记录踩过的坑和修法，方便复刻干净环境。所有结论都经过实测验证。

## 环境

- **VM**: OrbStack `ubuntu-24.04`（arm64, noble, Python 3.12）
- **xpra 服务端**: 6.4.3（xpra.org apt 源）+ 补丁，或 6.6（源码编译）
- **Mac 客户端**: 6.5.1（brew cask `/Applications/Xpra.app`）
- **启动**: `vm/start.sh`（起服务端 + Mac 附着）；`vm/wechat-topleft.sh`（微信主窗口归位看护）

---

## 1. 微信窗口不可见（黑屏/空白）— 九成是这个：窗口离屏

**症状**：微信在跑、服务端在编码发帧，但 Mac 上看不到窗口。
**真因**：微信会记住窗口位置，下次启动恢复。位置一旦被存成屏幕外坐标（实测见过 `30528,13344`、`17472,1648`），每次启动都恢复到屏幕外 → 看不见。**跟编码、xpra 版本无关。**
**自动修复**：`start.sh` 已集成 `wechat-topleft.sh`——客户端附着后，把微信主窗口（面积最大的那个，排除 44×44 托盘）拉到屏幕左上角 `(0,0)`，只动一次然后退出，之后用户可自行拖动。
**手动修复**：
```sh
orb -m ubuntu-24.04 bash -c '
  export PATH=/usr/local/bin:/usr/bin:/bin:$PATH
  info=$(xpra info :10 2>/dev/null)
  best=""; ba=0
  for w in $(printf "%s\n" "$info" | grep -aE "windows\.[0-9]+\.class-instance" | grep -ai wechat | grep -oE "windows\.[0-9]+" | cut -d. -f2); do
    s=$(printf "%s\n" "$info" | grep -aE "^windows\.$w\.size=" | grep -oE "[0-9]+, [0-9]+")
    W=$(printf "%s\n" "$s"|cut -d, -f1|tr -d " "); H=$(printf "%s\n" "$s"|cut -d, -f2|tr -d " ")
    [ -z "$W" ] && continue; a=$((W*H)); [ "$a" -gt "$ba" ] && { ba=$a; best=$w; }
  done
  [ -n "$best" ] && xpra control :10 move $best 0 0 && echo "moved $best to 0,0"
'
```
**注意**：**别动 44×44 的托盘窗口**——会触发 6.5.1 客户端的 `ClientTray.move_resize` 报错（见 #5）。主窗口是面积最大的那个（如 1960×1420）。

---

## 2. 拖文件进微信崩溃/重连 — 6.4.3 file_transfer NameError

**症状**：从 Mac 拖文件进微信，服务端崩、连接断、自动重连（看着像“崩溃重启”）。
**真因**：6.4.3 服务端 `xpra/net/file_transfer.py` 的 `_process_send_file` 里 `cancel()` 闭包，在拒绝路径上调用了未绑定的自由变量 `log`、`chunk` → `NameError` → 连接断。6.5+ 已原生修复。
**修法 A（6.4.3 + 补丁）**：在 `/usr/lib/python3/dist-packages/xpra/net/file_transfer.py` 的 `_process_send_file` 里，`chunk_id = options.strget("file-chunk-id")` 之后、`def cancel` 之前，加两行：
```python
        chunk = 0
        log = filelog
```
（镜像上游 6.6：`chunk = 0` 来自 commit `fefb9c362e9`，`log = filelog` 来自 `d8562cc517`。）
**修法 B（用 6.6）**：6.6 原生带这个修复，不用补丁。

---

## 3. 编译 6.6 源码：必须 Cython ≥ 3.1

**坑**：noble 的 apt `cython3` 是 **3.0.8**，在 Python 3.12 下会**静默产出坏的 `.so`**（`PyMemoryView_CheckExact` 符号问题）→ rgb 编解码器 import 失败被静默丢弃 → "cannot select rgb, using webp"。`setup.py` 的 `check_cython3()` 对 3.0.x **只 print 警告、不拦截**。
**修法**：
```sh
pip install --break-system-packages "cython>=3.1,<3.2"   # 装到 3.1.8
python3 setup.py build_ext --inplace                      # 从干净树首次构建
```
- **别设** `SETUPTOOLS_USE_DISTUTILS=stdlib`（Python 3.12 已移除 stdlib distutils，设了会让 setup.py 启动就崩，报 `you must install setuptools`）。
- **别半路升级**（先用 3.0.8 编、再升 3.1 + `--force` 会留陈旧 `.so`）。从头就用 3.1。
- 编完**必须验证**（构建 exit 0 ≠ 产物能用）：
  ```sh
  python3 -c "from xpra.codecs.argb import argb; print('argb OK')"   # rgb 编解码器没坏
  PYTHONPATH=. python3 fs/bin/xpra --version                          # 应显示 v6.6
  ```
- 用 6.6 跑：在 `/usr/local/bin/xpra` 放 wrapper 指向构建树：
  ```sh
  #!/bin/bash
  exec env PYTHONPATH=/home/lihu/xpra-6.6 python3 /home/lihu/xpra-6.6/fs/bin/xpra "$@"
  ```
  回退 = 删 wrapper（`xpra` 自动回退到 apt 的 6.4.3）。

---

## 4. Mac 客户端版本是 6.5.1（不是 6.6）

brew cask 装的是 6.5.1（`/Applications/Xpra.app`）。
**测版本的坑**：**别在 xpra dev 源码树目录（`/Users/lihu/git/xpra`）下跑 `Xpra --version`**——app 的 python 把 cwd 加进 `sys.path`，会 import 到 dev 树的 6.6 而不是 app 自带的 6.5.1，显示假的 "v6.6"。从 `/tmp` 等干净目录跑才准：
```sh
cd /tmp && /Applications/Xpra.app/Contents/MacOS/Xpra --version   # → xpra v6.5.1-r0
```

---

## 5. ClientTray.move_resize 报错（非致命）

**症状**：Mac 客户端日志刷 `TypeError: ClientTray.move_resize() takes 5 positional arguments but 6 were given`。
**真因**：6.5.1 客户端 bug——`manager.py:_process_window_move_resize` 调 `window.move_resize(x,y,w,h,resize_counter)`，但 `ClientTray.move_resize` 只收 `(x,y,w,h)`，漏了 `resize_counter`（普通窗口的 move_resize 有这个参数，托盘的没改）。
**影响**：非致命（被 try/except 接住），客户端不崩，只是那一帧托盘没移动。
**触发**：给托盘发 move_resize（如手动 move 托盘、或看护脚本误动托盘）。**别动托盘**就不会刷。

---

## 6. "cannot select rgb, using webp" 是正常现象，不是病

6.4.3 和 6.6 的编码选择逻辑**完全一致**（`update_encoding_selection`、`preforder`、`_encoders` 注册三处代码一字不差）：客户端请求 `rgb`（别名），但 `common_encodings` 里是 `rgb24`/`rgb32`（具体编码），别名匹配不上 → 掉 webp。**两版都这样**，不影响显示（webp 能渲染）。曾误判成“webp 不渲染导致黑屏”，实际是 #1 的窗口离屏。

---

## 7. 版本错配：6.4.3 服务端 + 6.5.1 客户端

6.5.1 客户端会发 `window-configure` 包，6.4.3 服务端不认（日志报 `unknown or invalid packet type 'window-configure'`）。6.6 服务端能认。所以 **6.6 服务端 + 6.5.1 客户端** 比 6.4.3 + 6.5.1 更干净（无 window-configure 报错）。

---

## 版本怎么选

| 方案 | 优点 | 缺点 |
|---|---|---|
| **6.4.3 apt + 补丁** | 预编译、简单、稳定 | 拖拽需手补丁；跟 6.5.1 客户端有 window-configure 报错（非致命） |
| **6.6 源码（wrapper）** | 原生拖拽修复、跟 6.5.1 客户端匹配更好 | 需在 VM 留构建树 + wrapper；`apt upgrade` 时注意别覆盖 |

**回退到 6.4.3 + 补丁**：
```sh
orb -m ubuntu-24.04 sudo rm /usr/local/bin/xpra     # 删 6.6 wrapper → xpra 回 6.4.3
orb -m ubuntu-24.04 /usr/bin/xpra stop :10          # 停 6.6
# 再跑 start.sh（补丁仍在 apt 的 file_transfer.py 里）
```
**切到 6.6**：按 #3 编译 + 放 wrapper，停 :10，用 wrapper 重起。

---

## 关键命令速查

```sh
# 会话/微信状态
orb -m ubuntu-24.04 xpra list
orb -m ubuntu-24.04 pgrep -x wechat

# 微信主窗口拉回左上角（见 #1，或直接跑看护）
orb -m ubuntu-24.04 sh /tmp/wechat-topleft.sh :10

# 测 Mac 客户端版本（务必从干净目录！见 #4）
cd /tmp && /Applications/Xpra.app/Contents/MacOS/Xpra --version

# 看 6.4.3 补丁在不在
orb -m ubuntu-24.04 grep -c "chunk = 0" /usr/lib/python3/dist-packages/xpra/net/file_transfer.py
# 应输出 2（补丁加的 + 原有的一处）

# 看服务端日志
orb -m ubuntu-24.04 tail -30 /run/user/501/xpra/10/server.log
```

---

## 复刻干净环境的步骤

1. `git clone` 这个 dotfiles 仓库，进 `wechat-remote/`。
2. VM 侧（OrbStack ubuntu-24.04）：按 README 装好 xpra（6.4.3 apt 或 6.6 源码），装微信。
3. 若用 6.4.3：打 #2 的两行补丁。若用 6.6：按 #3 编译 + 放 wrapper。
4. Mac 侧：`brew install --cask xpra`（6.5.1）。
5. 跑 `vm/start.sh`——它会起服务端、部署并后台跑 `wechat-topleft.sh`、Mac 附着。微信主窗口自动归位左上角。
6. 拖文件进微信验证（6.4.3 需补丁，6.6 原生）。
```
