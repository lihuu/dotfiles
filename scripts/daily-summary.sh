#!/usr/bin/env bash
#
# daily-summary.sh — 每日工作总结材料收集器
#
# 职责（纯 shell，不调用大模型、不写 Obsidian）：
#   1. 预检查：dotfiles 仓库今日是否有 git 提交或未提交改动
#      - 都没有 → 打印"今日无修改"并退出 0（零 token 跳过信号）
#   2. 有改动 → 收集今日 git 提交历史、未提交改动、zcode 对话历史
#      - 输出一段结构化 Markdown 到 stdout，供 ZCode cron 任务作为总结材料
#
# 实际的"调用大模型生成总结 + 写入 Obsidian"由 ZCode 内置 cron 完成：
#   - cron 每天 18:00 触发一段 prompt
#   - prompt 指示 ZCode 先跑 `bash scripts/daily-summary.sh` 做预检查
#   - 脚本输出"今日无修改"时 ZCode 直接结束（几乎不耗 token）
#   - 脚本输出材料时 ZCode 据此生成总结并写入 Obsidian
#
# 手动测试：
#   bash scripts/daily-summary.sh                              # 检查今天
#   SUMMARY_DATE=2026-07-23 bash scripts/daily-summary.sh      # 测试历史日期
#
# 环境变量覆盖（均有默认值）：
#   DOTFILES_DIR       仓库路径
#   SUMMARY_DATE       指定总结日期（YYYY-MM-DD），默认今天
#   ROLLOUT_DIR        zcode 对话历史目录

set -euo pipefail

# ================= 配置区域 =================
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/git/dotfiles}"
SUMMARY_DATE="${SUMMARY_DATE:-}"
ROLLOUT_DIR="${ROLLOUT_DIR:-$HOME/.zcode/cli/rollout}"

# ================= 日志辅助 =================
if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; YELLOW=$'\033[0;33m'
  RED=$'\033[0;31m'; NC=$'\033[0m'
else
  GREEN=''; BLUE=''; YELLOW=''; RED=''; NC=''
fi

log_info()    { printf '%s[INFO]%s %s\n' "$BLUE" "$NC" "$*" >&2; }
log_success() { printf '%s[OK]%s   %s\n' "$GREEN" "$NC" "$*" >&2; }
log_warn()    { printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
log_error()   { printf '%s[ERROR]%s %s\n' "$RED" "$NC" "$*" >&2; }
die()         { log_error "$*"; exit 1; }

# ================= 前置校验 =================
[[ -d "$DOTFILES_DIR/.git" ]] || die "不是 git 仓库: $DOTFILES_DIR"
command -v git >/dev/null 2>&1 || die "缺少命令: git"
command -v python3 >/dev/null 2>&1 || die "缺少命令: python3"

# 总结日期（YYYY-MM-DD），默认今天
if [[ -z "${SUMMARY_DATE:-}" ]]; then
  SUMMARY_DATE="$(date +%Y-%m-%d)"
fi
TODAY="$(date +%Y-%m-%d)"

# ================= 步骤 1: 纯 shell 预检查 =================
log_info "检查 ${DOTFILES_DIR} 在 ${SUMMARY_DATE} 的改动…"

cd "$DOTFILES_DIR"

# 今日提交数（用 git rev-list --count 计数，避免 --pretty=format 无尾换行导致 wc -l 少算）
COMMIT_COUNT="$(git rev-list --count \
  --since="${SUMMARY_DATE} 00:00:00" \
  --until="${SUMMARY_DATE} 23:59:59" \
  HEAD 2>/dev/null || echo 0)"

# 工作区未提交改动（仅当 SUMMARY_DATE 为今天时才有意义）
UNCOMMITTED_COUNT=0
if [[ "$SUMMARY_DATE" == "$TODAY" ]]; then
  UNCOMMITTED_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
fi

log_info "今日提交: ${COMMIT_COUNT} 条，未提交改动: ${UNCOMMITTED_COUNT} 项"

if (( COMMIT_COUNT == 0 && UNCOMMITTED_COUNT == 0 )); then
  log_success "今日无修改，跳过总结"
  # 输出一行明确信号，供 ZCode cron 识别并直接结束
  echo "NO_CHANGES"
  exit 0
fi

# ================= 步骤 2: 收集材料到 stdout =================
# A. git 提交历史（含 body）
echo "## 今日 Git 提交（${SUMMARY_DATE}）"
echo ""
if (( COMMIT_COUNT > 0 )); then
  git log \
    --since="${SUMMARY_DATE} 00:00:00" \
    --until="${SUMMARY_DATE} 23:59:59" \
    --pretty=format:'### %h — %s%n- 时间: %ai%n- 作者: %an%n%n%b%n' 2>/dev/null || true
else
  echo "_无提交_"
fi
echo ""

# B. 未提交改动概览
echo "## 当前未提交改动"
echo ""
if (( UNCOMMITTED_COUNT > 0 )); then
  echo '```'
  git status --porcelain 2>/dev/null || true
  echo '```'
  echo ""
  echo "改动统计:"
  echo '```'
  git diff --stat 2>/dev/null || true
  git diff --cached --stat 2>/dev/null || true
  echo '```'
else
  echo "_无未提交改动_"
fi
echo ""

# C. zcode 对话历史（运行时扫描 rollout）
# 将 startedAt（UTC）转换为本地时区后再与 SUMMARY_DATE 比较，按 turnId 去重
# 只提取真实用户输入，过滤 system-reminder / command 等系统注入内容
echo "## 今日 ZCode 对话历史（${SUMMARY_DATE}）"
echo ""
python3 - "$SUMMARY_DATE" "$ROLLOUT_DIR" <<'PYEOF'
import json, glob, os, sys, datetime

target_date = sys.argv[1]
rollout_dir = sys.argv[2]

if not os.path.isdir(rollout_dir):
    print("_无对话历史（rollout 目录不存在）_")
    sys.exit(0)

def to_local_date(iso_ts):
    try:
        dt = datetime.datetime.fromisoformat(iso_ts.replace('Z', '+00:00'))
        return dt.astimezone().date().isoformat()
    except Exception:
        return ''

def user_prompt(d):
    """取第一条真实 user 消息，跳过系统注入的 system-reminder / command 等。"""
    for m in d.get('request', {}).get('messages', []):
        if m.get('role') != 'user':
            continue
        c = m.get('content')
        if isinstance(c, list):
            continue  # tool_result 数组，跳过
        if not isinstance(c, str):
            try:
                c = json.dumps(c, ensure_ascii=False)
            except Exception:
                continue
        s = c.lstrip()
        if s.startswith('<system-reminder>'):
            continue
        if s.startswith('<command-name>'):
            continue
        if s.startswith('<command-message>'):
            continue
        if s.startswith('Caveat:') or s.startswith('[Request interrupted'):
            continue
        return c
    return ''

seen = {}  # turnId -> {startedAt, prompt}
for f in sorted(glob.glob(os.path.join(rollout_dir, '*.jsonl'))):
    try:
        with open(f, encoding='utf-8') as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                started = d.get('startedAt', '')
                if to_local_date(started) != target_date:
                    continue
                turn = d.get('turnId')
                if not turn or turn in seen:
                    continue
                sid = d.get('sessionId', '')
                if 'subagent' in sid:
                    continue
                prompt = user_prompt(d)
                if not prompt:
                    continue
                seen[turn] = {'startedAt': started, 'prompt': prompt}
    except Exception:
        continue

if not seen:
    print("_今日无 zcode 对话历史（可能会话已结束被清理）_")
else:
    rows = sorted(seen.values(), key=lambda r: r['startedAt'])
    for i, r in enumerate(rows, 1):
        try:
            dt = datetime.datetime.fromisoformat(r['startedAt'].replace('Z', '+00:00')).astimezone()
            local_ts = dt.strftime('%H:%M:%S')
        except Exception:
            local_ts = r['startedAt']
        prompt = r['prompt'].replace('\n', ' ')
        if len(prompt) > 300:
            prompt = prompt[:300] + '…'
        print(f"{i}. [{local_ts}] {prompt}")
PYEOF
echo ""

log_success "材料收集完成，已输出到 stdout"