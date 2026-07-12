#!/bin/zsh
# test-tidy-zshrc.zsh — tidy-zshrc 脚本测试
#
# 测试用例：
#   1. 干净状态（无安装器标记）→ 报告干净，不动文件
#   2. 配对标记 >>>/<<< → 检测 + 搬迁
#   3. block begin/end 配对 → 检测 + 搬迁
#   4. Added by 单行标记 → 检测 + 搬迁（靠空行定界）
#   5. 无标记的手写内容不误判
#   6. --apply 后入口移除块、.local 收到块
#   7. --dry-run 绝不修改文件
set -euo pipefail

tidy="$HOME/.zshrc.d/tidy-zshrc"

if [[ ! -x "$tidy" ]]; then
    print -u2 -- "找不到 tidy-zshrc: $tidy"
    exit 69
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fake_zshrc="$tmpdir/.zshrc"
fake_local="$tmpdir/.zshrc.local"

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        print -- "  ✅ $desc"
    else
        print -u2 -- "  ❌ $desc"
        print -u2 -- "    expected: $expected"
        print -u2 -- "    actual:   $actual"
        diff -u <(print -r -- "$expected") <(print -r -- "$actual") >&2 || true
        exit 1
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        print -- "  ✅ $desc"
    else
        print -u2 -- "  ❌ $desc"
        print -u2 -- "    期望包含: $needle"
        print -u2 -- "    实际内容: $haystack"
        exit 1
    fi
}

export ZSHRC_TARGET="$fake_zshrc"
export ZSHRC_LOCAL_TARGET="$fake_local"

# ============================================================
# 用例 1：干净状态（只有手写内容，无安装器标记）
# ============================================================
print -- "用例 1: 干净状态（无安装器标记）"
cat > "$fake_zshrc" <<'EOF'
# 我的 .zshrc
echo "hello"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
EOF
: > "$fake_local"

output=$("$tidy" 2>&1 || true)
assert_eq "报告干净" "✅ ~/.zshrc 干净，未检测到安装器注入块。" "$output"
assert_contains "入口未改（仍有 opencode）" "$(cat "$fake_zshrc")" 'opencode'
assert_eq ".local 仍为空" "" "$(cat "$fake_local")"

# ============================================================
# 用例 2：配对标记 >>> / <<<
# ============================================================
print -- ""
print -- "用例 2: >>> / <<< 配对标记"
cat > "$fake_zshrc" <<'EOF'
# 我的入口

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
# <<< grok installer <<<
EOF
: > "$fake_local"

output=$("$tidy" 2>&1 || true)
assert_contains "检测到 grok 块" "$output" 'grok installer'
assert_contains "块内容含 export PATH" "$output" '.grok/bin'
# 预览模式不改文件
assert_contains "预览不改入口" "$(cat "$fake_zshrc")" 'grok installer'
assert_eq "预览不改 .local" "" "$(cat "$fake_local")"

# ============================================================
# 用例 3：block begin / end 配对
# ============================================================
print -- ""
print -- "用例 3: block begin / end 配对"
cat > "$fake_zshrc" <<'EOF'
# 入口

# Qwen Code PATH block begin
export PATH="$HOME/.local/bin":$PATH
# Qwen Code PATH block end
EOF
: > "$fake_local"

output=$("$tidy" 2>&1 || true)
assert_contains "检测到 Qwen 块" "$output" 'Qwen Code'
assert_contains "块内容含 .local/bin" "$output" '.local/bin'
# 预览不改文件
assert_contains "预览不改入口" "$(cat "$fake_zshrc")" 'block begin'

# ============================================================
# 用例 4：Added by 单行标记（靠空行定界）
# ============================================================
print -- ""
print -- "用例 4: Added by 单行标记"
cat > "$fake_zshrc" <<'EOF'
# 入口

# Added by Antigravity IDE
export PATH="$HOME/.antigravity-ide/bin:$PATH"

# 这是我手写的，不该被搬走
export PATH="$HOME/Documents/scripts:$PATH"
EOF
: > "$fake_local"

output=$("$tidy" 2>&1 || true)
assert_contains "检测到 Added by 块" "$output" 'Added by Antigravity'
assert_contains "块内容含 antigravity-ide" "$output" 'antigravity-ide'
# 手写内容不应被检测为块
assert_contains "不误判手写内容" "$output" '1 个安装器'

# ============================================================
# 用例 5：混合三种标记 + 手写内容，--apply 完整流程
# ============================================================
print -- ""
print -- "用例 5: 混合标记 + --apply 完整流程"
cat > "$fake_zshrc" <<'EOF'
# 我的入口
echo "hi"

# Added by SomeTool
export PATH="/some/bin:$PATH"

# >>> another-installer >>>
export PATH="/another/bin:$PATH"
# <<< another-installer <<<

# 手写注释，不搬
export EDITOR=vim

# Qwen Code PATH block begin
export PATH="/qwen/bin:$PATH"
# Qwen Code PATH block end
EOF
: > "$fake_local"

# --apply
output=$(echo "y" | "$tidy" --apply 2>&1 || true)
assert_contains "提示备份" "$output" '已备份'
assert_contains "提示搬入" "$output" '已搬入'
assert_contains "提示移除" "$output" '已从'

# 入口应该只剩手写内容
zshrc_after=$(cat "$fake_zshrc")
assert_contains "入口保留手写 echo" "$zshrc_after" 'echo "hi"'
assert_contains "入口保留手写 EDITOR" "$zshrc_after" 'export EDITOR=vim'
# 不应再包含安装器块
if [[ "$zshrc_after" == *"Added by SomeTool"* ]] || \
   [[ "$zshrc_after" == *"another-installer"* ]] || \
   [[ "$zshrc_after" == *"block begin"* ]]; then
    print -u2 -- "  ❌ 入口仍含安装器块"
    exit 1
fi
print -- "  ✅ 入口已移除所有安装器块"

# .local 应包含三个块的内容
local_after=$(cat "$fake_local")
assert_contains ".local 收到 SomeTool" "$local_after" '/some/bin'
assert_contains ".local 收到 another" "$local_after" '/another/bin'
assert_contains ".local 收到 Qwen" "$local_after" '/qwen/bin'
assert_contains ".local 有时间戳注释" "$local_after" 'tidy-zshrc'

# ============================================================
print -- ""
print -- "PASS: tidy-zshrc"