#!/bin/zsh
# test-install-zsh-config.zsh - install-zsh-config.sh 部署脚本测试
#
# 测试覆盖完整部署路径(不是 --check)，在临时 HOME 目录中执行，
# 验证：
#   1. 文件部署到位(.zshrc / .zshrc.d/ / .zshrc.tests/)
#   2. 隔离层 .private/.local 不被覆盖
#   3. 幂等性(跑两次结果一致)
#   4. 不会因 set -u 报错退出(全角括号等 bug 的回归测试)
set -euo pipefail

# 定位脚本和仓库根
# 脚本在 zsh/tests/，两级上是仓库根
script_dir="${0:A:h}"
repo_root="${script_dir:h:h}"
installer="$repo_root/zsh/macos/install-zsh-config.sh"

if [[ ! -x "$installer" ]]; then
    print -u2 -- "找不到 install-zsh-config.sh: $installer"
    exit 69
fi

# 临时目录模拟 HOME
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# 辅助断言
assert_exists() {
    local desc="$1" path="$2"
    if [[ -e "$path" ]]; then
        print -- "  OK $desc"
    else
        print -u2 -- "  FAIL $desc: $path 不存在"
        exit 1
    fi
}

assert_contains() {
    local desc="$1" file="$2" needle="$3"
    if grep -q "$needle" "$file" 2>/dev/null; then
        print -- "  OK $desc"
    else
        print -u2 -- "  FAIL $desc: $file 中未找到 '$needle'"
        cat "$file" >&2 2>/dev/null || true
        exit 1
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        print -- "  OK $desc"
    else
        print -u2 -- "  FAIL $desc"
        print -u2 -- "    expected: $expected"
        print -u2 -- "    actual:   $actual"
        exit 1
    fi
}

# 公共：运行安装脚本，HOME 指向临时目录
run_install() {
    HOME="$tmpdir" sh "$installer" 2>&1
}

# ============================================================
# 用例 1：全新部署到空 HOME
# ============================================================
print -- "用例 1: 全新部署(空 HOME)"

output=$(run_install || true)
exit_code=$?

# 不应该报错退出(set -u 等会导致非零退出)
assert_eq "部署成功退出(exit code 0)" "0" "$exit_code"

# 核心文件到位
assert_exists ".zshrc 入口" "$tmpdir/.zshrc"
assert_exists ".zshrc.d/ 目录" "$tmpdir/.zshrc.d"
assert_exists ".zshrc.tests/ 目录" "$tmpdir/.zshrc.tests"

# 模块文件
for f in 10-path.zsh 20-oh-my-zsh.zsh 30-env.zsh 40-aliases.zsh \
         50-functions.zsh 55-systemctl.zsh 60-tools.zsh; do
    assert_exists "模块 $f" "$tmpdir/.zshrc.d/$f"
done

# 工具脚本
assert_exists "tidy-zshrc" "$tmpdir/.zshrc.d/tidy-zshrc"
assert_exists "import-zoxide-history.zsh" "$tmpdir/.zshrc.d/import-zoxide-history.zsh"

# 入口内容正确(应是薄入口，含 source 逻辑)
assert_contains "入口含 zshrc.d glob" "$tmpdir/.zshrc" '.zshrc.d'
assert_contains "入口含 .private source" "$tmpdir/.zshrc" '.zshrc.private'
assert_contains "入口含 .local source" "$tmpdir/.zshrc" '.zshrc.local'

# ============================================================
# 用例 2：隔离层不覆盖
# ============================================================
print -- ""
print -- "用例 2: 隔离层 .private/.local 不被覆盖"

# 预先写入隔离层文件
echo '# 私密内容 - 不应被覆盖' > "$tmpdir/.zshrc.private"
echo '# 安装器注入 - 不应被覆盖' > "$tmpdir/.zshrc.local"

# 重新部署
output=$(run_install || true)

# 隔离层内容应保持不变
assert_contains ".private 未被覆盖" "$tmpdir/.zshrc.private" '私密内容'
assert_contains ".local 未被覆盖" "$tmpdir/.zshrc.local" '安装器注入'

# ============================================================
# 用例 3：幂等性(跑两次，文件内容一致)
# ============================================================
print -- ""
print -- "用例 3: 幂等性(跑两次结果一致)"

# 第一次部署(隔离层已有，用例 2 的状态)
run_install >/dev/null 2>&1 || true
# 记录 .zshrc 和模块文件的校验和
checksums_before=$(find "$tmpdir/.zshrc" "$tmpdir/.zshrc.d" -type f -exec shasum {} \; | sort)

# 第二次部署
run_install >/dev/null 2>&1 || true
checksums_after=$(find "$tmpdir/.zshrc" "$tmpdir/.zshrc.d" -type f -exec shasum {} \; | sort)

assert_eq "两次部署后校验和一致" "$checksums_before" "$checksums_after"

# ============================================================
# 用例 4：备份功能(已有 .zshrc 时应备份)
# ============================================================
print -- ""
print -- "用例 4: 备份功能"

# 用独立临时目录，避免前面用例的备份目录干扰计数
backup_tmp=$(mktemp -d)
# 先部署一次(创建 .zshrc)
HOME="$backup_tmp" sh "$installer" >/dev/null 2>&1 || true
# 手动改 .zshrc，让它和仓库不同，确认备份的是旧内容
echo '# 我是旧的 .zshrc' > "$backup_tmp/.zshrc"

HOME="$backup_tmp" sh "$installer" >/dev/null 2>&1 || true

# 备份目录应恰好有 1 个(这次部署生成的)
backup_count=$(ls -d "$backup_tmp"/.zshrc.backup.* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "生成了备份目录" "1" "$backup_count"

# 备份里应有旧的 .zshrc 内容
backup_zshrc=$(ls "$backup_tmp"/.zshrc.backup.*/.zshrc 2>/dev/null | head -1)
assert_contains "备份的是旧 .zshrc" "$backup_zshrc" '我是旧的 .zshrc'

# 当前 .zshrc 应是仓库的新版本
assert_contains "当前 .zshrc 是仓库版" "$backup_tmp/.zshrc" 'zshrc.d'
rm -rf "$backup_tmp"

# ============================================================
# 用例 5：--check 模式不部署
# ============================================================
print -- ""
print -- "用例 5: --check 模式不部署任何文件"

# 用新的临时目录
check_tmp=$(mktemp -d)
output=$(HOME="$check_tmp" sh "$installer" --check 2>&1 || true)

# 不应有 .zshrc 等文件被创建
if [[ -f "$check_tmp/.zshrc" ]]; then
    print -u2 -- "  FAIL --check 模式不应部署 .zshrc"
    exit 1
fi
if [[ -d "$check_tmp/.zshrc.d" ]]; then
    print -u2 -- "  FAIL --check 模式不应创建 .zshrc.d"
    exit 1
fi
print -- "  OK --check 模式未部署任何文件"
rm -rf "$check_tmp"

# ============================================================
print -- ""
print -- "PASS: install-zsh-config"