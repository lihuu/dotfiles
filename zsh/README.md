# zsh 配置（macOS / Linux 通用）

本目录管理 zsh 的完整配置体系，覆盖 macOS 与 Linux（含 WSL）。采用三层隔离结构 + 模块化加载 + 双向同步模型，保证仓库与真实环境长期一致、可迁移、可回滚。

## 目录结构

```text
zsh/
├── install-zsh-config.sh     # 统一安装器（自动检测平台，macOS/Linux 通用）
├── AGENTS.md                 # 本目录的 AI 协作约束（修改前必读）
├── macos/                    # macOS 专用配置
│   ├── .zshrc                # 薄入口（三层拼装）
│   ├── zshrc.d/              # 主配置模块（编号控制加载顺序）
│   ├── completions/          # 自定义补全（_*，部署到 ~/.zsh/completions/）
│   ├── tidy-zshrc            # 安装器注入清理脚本
│   └── install-zsh-config.sh # macOS 专用安装器（历史保留）
└── linux/                    # Linux / WSL 专用配置
    ├── .zshrc                # 薄入口（三层拼装）
    ├── zshrc.d/              # 主配置模块
    ├── install-zsh-config.sh # Linux 专用安装器（历史保留）
    └── .zshrca               # 旧单文件配置遗留（未启用）
```

> **统一入口**：`zsh/install-zsh-config.sh` 自动检测平台，选择对应目录；平台目录下的旧安装器保留兼容，新部署一律用统一入口。

## 三层隔离结构

```text
~/.zshrc              薄入口，只负责按顺序 source 三个层，不承载具体配置
~/.zshrc.d/*.zsh      主配置模块（可分享，进仓库，按编号顺序加载）
~/.zshrc.private      秘密层（API key / token，绝不进仓库）
~/.zshrc.local        安装器注入 + 机器专属 PATH 治理（不进仓库）
```

- **可分享配置**（alias、函数、环境变量、PATH、工具初始化）→ `~/.zshrc.d/` 对应模块
- **秘密**（密钥/token/密码）→ `~/.zshrc.private`，任何情况下不进仓库
- **安装器注入**（codex、grok 等 CLI 往 `.zshrc` 塞的标记块）→ 手动搬入 `~/.zshrc.local`

## 模块化规则

`zshrc.d/` 下文件按数字前缀加载（小→大），依赖顺序为硬约束：

| 编号 | 模块 | 职责 |
|---|---|---|
| `10-path.zsh` | PATH 架构 | `add_to_path` 函数定义 |
| `20-oh-my-zsh.zsh` | oh-my-zsh 引导 | theme / plugins / source |
| `25-completion.zsh` | 补全增强 | Tab 菜单选择 |
| `30-env.zsh` | 环境变量 | env + PATH 组装 |
| `40-aliases.zsh` | alias | 别名集合 |
| `50-functions.zsh` | 函数 | 工具函数（平台差异见各平台目录） |
| `55-systemctl.zsh` | 平台服务封装 | **仅 macOS**（launchd 封装）；Linux 用原生 systemctl |
| `60-tools.zsh` | 工具初始化 | fzf / zoxide / brew / mise 等 |

新增模块须保持语义对齐：PATH 架构在 env 之前、工具初始化在最后。

## 安装

### 1. 前置准备（手动，一次性）

| 软件 | macOS | Linux/WSL |
|---|---|---|
| zsh | `brew install zsh` | `apt install zsh` + `chsh -s /usr/bin/zsh` |
| oh-my-zsh | `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"` | 同左 |
| Homebrew | `brew install git`（自带） | Linuxbrew 官方脚本 |

### 2. 部署配置

```sh
sh zsh/install-zsh-config.sh          # 自动检测平台并部署
```

部署时自动处理：

- **Linux**：zoxide / fzf / thefuck / bat / vim 为必需依赖，缺失时用 brew 自动安装（`--check` 只检测不安装）
- **macOS**：同上工具为建议依赖，缺失仅警告；brew 可用时也会尝试安装
- 备份现有 `~/.zshrc`、`~/.zshrc.d` 到 `~/.zshrc.backup.<时间戳>/`
- 部署 `~/.zsh/completions/`（macOS 有自定义补全）、`~/.zshrc.tests/`、`~/.zshrc.scripts/`（tidy-zshrc）
- 不覆盖 `~/.zshrc.private` / `~/.zshrc.local`

### 3. 部署后

```sh
# 从旧机器拷贝秘密层（不能走 git）
scp old-machine:.zshrc.private ~/
# 生效
source ~/.zshrc
```

## 双向同步（仓库 ↔ 环境）

复制部署下，仓库与环境可能各自改动。安装器提供三种同步模式：

```sh
sh zsh/install-zsh-config.sh            # 仓库 → 环境（部署，覆盖模块与入口）
sh zsh/install-zsh-config.sh --diff     # 只读对比两边差异（退出码 1 = 有差异）
sh zsh/install-zsh-config.sh --pull     # 环境 → 仓库（先看差异，确认后回写）
```

### 同步边界（保证不冲突）

| 层 | 同步方向 | 原因 |
|---|---|---|
| `~/.zshrc.d/` 模块 | 双向（diff / pull / push） | 两边都可能改 |
| `~/.zshrc` 薄入口 | 单向（仓库 → 环境） | 环境侧会被安装器污染，以仓库为准 |
| `~/.zshrc.private` / `.local` | 永不进仓库 | 秘密 + 机器专属 |

### 典型工作流

```sh
# 改仓库配置 → 同步到环境
sh zsh/install-zsh-config.sh

# 在环境里改模块 → 同步回仓库
sh zsh/install-zsh-config.sh --diff    # 先看差异
sh zsh/install-zsh-config.sh --pull    # 确认后回写仓库
git diff zsh/macos/zshrc.d/            # review
git commit -m "..." && git push
```

## 回滚

```sh
# 用部署时的备份恢复
cp ~/.zshrc.backup.<时间戳>/.zshrc ~/.zshrc
rm -rf ~/.zshrc.d
```

## 平台差异

| 项 | macOS | Linux/WSL |
|---|---|---|
| 配置目录 | `zsh/macos/` | `zsh/linux/` |
| Homebrew | `/opt/homebrew`（Apple Silicon） | `/home/linuxbrew/.linuxbrew` |
| systemctl | 函数封装 launchd（55-systemctl.zsh） | 原生 systemctl |
| 依赖策略 | 缺失仅警告 | 必需依赖自动安装 |
| 自定义补全 | 有（_systemctl） | 无 |
| tidy-zshrc | 有 | 无 |
| 路径写法 | `$HOME` 相对 | `$HOME` 相对（Linuxbrew 固定前缀除外） |

## 测试

```sh
# macOS（仓库侧测试）
zsh zsh/tests/test-import-zoxide-history.zsh
zsh zsh/tests/test-tidy-zshrc.zsh
```

任何 zsh 配置改动后必须跑上述测试。

## 安全基线

- `~/.zshrc.private` 含最高敏感级凭据，严禁出现在仓库/日志/issue/commit message
- zoxide 数据库（`~/.local/share/zoxide/db.zo`）不要提交到公开仓库
- 本仓库是公开仓库，提交前检查无 IP、用户名、密钥等个人信息
