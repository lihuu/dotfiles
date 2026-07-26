# mise — 多语言版本管理

本目录存放 mise 相关的配置与加载脚本。

## 两种激活模式

mise 有两种激活方式，分别覆盖不同场景：

| 模式 | 命令 | 配置位置 | 适用场景 |
|------|------|---------|---------|
| **PATH 模式** | `mise activate zsh` | `zsh/macos/zshrc.d/60-tools.zsh` | 交互式终端，按目录 `.mise.toml` 动态切换版本 |
| **shims 模式** | `source mise/activate-shims.sh` | 自动化脚本里手动 source | cron / launchd / SSH 单命令 / Makefile / 任何非交互 shell |

两者互不冲突，可并存：交互终端用 PATH 模式，自动化场景按需 source shims 脚本。

## 前置条件（重要）

**shims 模式生效的前提：mise 二进制本身在当前 shell 的 PATH 里可达。**

`activate-shims.sh` 用 `command -v mise` 判断 mise 是否安装，找不到就静默跳过（避免新机器报错）。这意味着：

- SSH 单命令（`ssh host 'cmd'`）、cron、脚本等非交互场景下，mise 必须已在 PATH 中
- mise 默认安装位置 `~/.local/bin`（手动安装）或 `/opt/homebrew/bin`（brew 安装）
- 这些目录默认**不在** SSH 单命令的极简 PATH 里

### 解决：在 `~/.zshenv` 加 PATH

`~/.zshenv` 是所有 zsh 调用（含 SSH 单命令、脚本）都会加载的文件，是让 mise 在全场景可达的正确位置。

在 `~/.zshenv` 加入（按你的 mise 安装位置调整）：

```sh
# mise 等用户级工具的安装位置，放 zshenv 确保非交互 shell 也能找到
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
```

注意 `~/.zshenv` 是机器本地文件，不在本仓库管理范围内，需在每台机器手动配置。

`~/.zprofile`（仅 login shell 加载）覆盖不到 SSH 单命令场景，不能依赖它。

## 使用方式

### 交互式终端

无需额外操作。`zsh/macos/zshrc.d/60-tools.zsh` 已配置 PATH 模式自动激活。

### 自动化脚本

在脚本顶部 source 加载片段：

```sh
. "$HOME/git/dotfiles/mise/activate-shims.sh"
# 之后该进程及其子进程都能直接调用 mise 管理的 node/python/...
```

### cron / launchd

```cron
* * * * * . $HOME/git/dotfiles/mise/activate-shims.sh && node /path/to/job.js
```

### Makefile

```makefile
all:
	. $$HOME/git/dotfiles/mise/activate-shims.sh && node build.js
```

## 验证

激活后用以下命令确认：

```sh
# 交互模式
type mise              # 应显示 shell function
mise doctor           # activated: yes, shims_on_path: no（PATH 模式正常表现）

# shims 模式（自动化场景）
. ~/git/dotfiles/mise/activate-shims.sh
which node            # 应指向 ~/.local/share/mise/shims/node
node -v               # mise 管理的版本
```

`mise doctor` 显示 `shims_on_path: no` 是 **PATH 模式的正常状态**，不是错误。只有用 `mise activate --shims` 时才会显示 yes。

## 新机器初始化步骤

1. 安装 mise：
   - macOS：`brew install mise`（装到 `/opt/homebrew/bin`）或从 [GitHub releases](https://github.com/jdx/mise/releases) 下载二进制到 `~/.local/bin`
   - Linux：同上，或用官方脚本 `curl -fsSL https://mise.run | sh`
2. 在 `~/.zshenv` 加 PATH（见上文"前置条件"）
3. 跑 `sh zsh/macos/install-zsh-config.sh` 同步 zsh 配置（启用 PATH 模式）
4. `mise use --global node@<版本>` 设全局默认工具版本
5. 验证两种模式都工作

## 国内网络注意事项

`mise install node@<版本>` 默认从 nodejs.org 下载，国内可能超时。可用环境变量切镜像：

```sh
# 临时
MISE_NODE_MIRROR_URL=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/ mise install node@22

# 永久（写入 ~/.config/mise/config.toml）
mise config set node.mirror_url https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/
```

可用的国内镜像：
- 清华：`https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/`
- npmmirror：`https://npmmirror.com/mirrors/node/`