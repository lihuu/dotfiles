# zsh/AGENTS.md

本文件是 zsh 配置的专项 AI 协作约束。根目录 `AGENTS.md` 仍是全局规则入口，本文件只管 zsh 相关内容，两者冲突时以本文件为准。

## 配置架构

本仓库的 zsh 配置采用三层隔离结构，理解它才能正确修改：

```
~/.zshrc              薄入口，只负责按顺序 source 三个层，不承载具体配置
~/.zshrc.d/*.zsh      主配置模块（可分享，进仓库，按编号顺序加载）
~/.zshrc.private       秘密层（API key / token，绝不进仓库）
~/.zshrc.local         安装器注入 + 机器专属 PATH 治理（不进仓库）
```

仓库中的对应位置：

- `zsh/macos/.zshrc` — 薄入口模板
- `zsh/macos/zshrc.d/` — 主配置模块（6 个文件，编号前缀控制加载顺序）
- `zsh/macos/tidy-zshrc` — 安装器注入清理脚本
- `zsh/tests/` — 测试（改配置必须跑）

Linux 配置（`zsh/linux/`）独立于本结构，本次不涉及。

## 分层规则

处理 zsh 配置时，必须遵守以下分层纪律：

- **可分享配置**（alias、函数、非秘密环境变量、PATH 架构、工具初始化）一律进 `zsh/macos/zshrc.d/` 对应模块，不写进 `.zshrc` 入口
- **秘密**（密钥、token、密码、私钥）只能放 `~/.zshrc.private`，严禁写进仓库任何文件
- **安装器注入**（`# >>> marker >>>`、`# Added by`、`# xxx block begin` 等标记块）只能进 `~/.zshrc.local`，严禁写进仓库
- **机器专属路径治理**（如 codex-env-policy 之类的 PATH 重排块）属于安装器副产物，进 `.local`，不进仓库

## 模块化规则

`zsh/macos/zshrc.d/` 下的文件必须遵守：

- 文件名以数字前缀开头（`10-`、`20-`、…），数字代表加载顺序，数字小的先加载
- 扩展名必须为 `.zsh`，否则不会被入口的 glob 匹配加载
- 禁止无前缀文件或非 `.zsh` 扩展名文件（`tidy-zshrc` 例外，它是工具不是模块，特意无 `.zsh` 扩展名避免被 source）
- 新增模块时，编号要和现有模块语义对齐（PATH 架构在 env 之前、工具初始化在最后）

加载顺序的硬约束：

1. `10-path.zsh` — `add_to_path` 函数定义（后续模块要调用）
2. `20-oh-my-zsh.zsh` — oh-my-zsh 引导（theme/plugins/source）
3. `30-env.zsh` — 环境变量 + `add_to_path` 调用 + PATH 组装（依赖 env 变量，所以调用必须在 env 定义之后）
4. `40-aliases.zsh` — alias
5. `50-functions.zsh` — 函数
6. `60-tools.zsh` — 工具初始化（fzf/zoxide/thefuck/bun，依赖 PATH 和 env 都就绪）

如果新增模块违反这个依赖顺序，PATH 项会因变量为空而丢失。

## 安装器注入处理

各类 CLI 安装器（codex、Antigravity、Qwen、grok 等）会往 `~/.zshrc` 末尾追加内容，造成"漂移"。处理方式：

- 不要手动从 `~/.zshrc` 删安装器块
- 运行 `zsh/macos/tidy-zshrc` 预览漂移，确认后 `--apply` 自动搬迁到 `~/.zshrc.local`
- `tidy-zshrc` 只识别带安装器标记的块，不会误碰手写内容
- 清理后入口恢复成仓库版薄入口，安装器内容进入 `.local`（不进仓库）

`tidy-zshrc` 识别的三种标记格式：

- `# >>> marker >>>` ... `# <<< marker <<<`（配对）
- `# xxx block begin` ... `# xxx block end`（配对）
- `# Added by xxx` + 紧跟的非空行（单行标记，靠空行定界）

如果遇到不在这三种格式内的安装器注入，应该扩展 `tidy-zshrc` 的识别规则，而不是手动处理。

## zoxide 收录策略

zoxide 用 `--hook none` 关掉默认收录，由自定义 `my_zoxide_add` 函数接管 `chpwd` 钩子。规则：

- **白名单前缀**（`~/git/`、`~/MyFiles/`、`~/ZCodeProject/`）下才检查 `.git`；不在白名单内的目录直接收录，跳过 git 检查（省 stat 开销）
- **在 git 仓库内**：只收录 repo 根目录，不收录子目录（避免 `j hermes` 命中 `~/Code/Hermes/src` 等子目录）
- **非 git 目录**或**白名单内但无 `.git`**：正常收录当前目录
- 新增仓库区时，往 `my_zoxide_add` 的 `case` 里加一行前缀即可

修改 `my_zoxide_add` 时注意：

- 不要改回 `--hook pwd`（默认 hook 会收录所有子目录，包括 git 子目录）
- 白名单前缀用 `$HOME` 变量，不硬编码路径
- 函数注册用 `chpwd_functions+=(my_zoxide_add)`，不要覆盖已有的 chpwd 函数

## 禁止行为

- 禁止往 `zsh/macos/.zshrc` 里塞具体配置（alias/env/函数/安装器内容），入口只做 source
- 禁止在模块文件里写硬编码绝对路径 `/Users/...`，必须用 `$HOME`
- 禁止提交 `~/.zshrc.private` 或 `~/.zshrc.local` 的内容到仓库
- 禁止覆盖 `cd` 的原生行为（zoxide 用 `--cmd j` 生成独立命令，不动 `cd`）
- 禁止把仓库版 `.zshrc` 改成 `alias j="z"`（那会退化成字符替换，丢失 zoxide 的排序/交互能力）

## 变更流程

修改 zsh 配置时：

1. 先理解现有模块结构和加载顺序，不凭空假设
2. 改对应的 `zsh/macos/zshrc.d/` 模块，不入口文件里堆配置
3. 改完跑 `zsh/tests/` 下的测试，两个测试（`test-import-zoxide-history.zsh`、`test-tidy-zshrc.zsh`）都要过
4. 如果改了入口结构，同步更新 `zsh/AGENTS.md` 的架构描述
5. 硬编码路径变量化为 `$HOME`，保证可迁移
6. 如果改动影响 PATH 组装逻辑，在新 zsh 实例里验证 PATH 完整性

## 测试要求

- `zsh/tests/test-import-zoxide-history.zsh` — 测试 zoxide 历史导入
- `zsh/tests/test-tidy-zshrc.zsh` — 测试安装器清理脚本（5 个用例：干净状态、三种标记格式、混合 + apply）

跑测试：
```sh
zsh zsh/tests/test-import-zoxide-history.zsh
zsh zsh/tests/test-tidy-zshrc.zsh
```

任何 zsh 配置改动，两个测试必须全部 PASS。如果新增模块，应该补对应测试。

## 安全基线

继承根 `AGENTS.md` 的安全基线，额外强调：

- zoxide 数据库（`~/.local/share/zoxide/db.zo`）可备份迁移，但不要把含个人使用路径频率的数据库提交到公开仓库
- `~/.zshrc.private` 里的 API key/token 是最高敏感级别，任何情况下不能出现在仓库、日志、issue、commit message 中
- `tidy-zshrc` 搬迁到 `.local` 的内容可能含机器路径，虽然 `.local` 不进仓库，但不要把 `.local` 内容贴到任何外部场合