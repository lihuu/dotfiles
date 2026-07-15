# 55-systemctl.zsh - systemctl 风格的 launchd 管理函数
#
# 平台预判断：模块加载时一次性确定，函数体内不做平台判断。
#   macOS  -> 定义 launchctl 封装版 systemctl
#   Linux  -> 不定义函数，直接用系统原生 systemctl（零开销透传）
#
# 用法（macOS）：
#   systemctl list                 列出第三方服务（过滤 com.apple.*）
#   systemctl status <svc>         查看服务状态（支持模糊匹配）
#   systemctl start <svc>          启动服务
#   systemctl stop <svc>           停止服务（SIGTERM）
#   systemctl restart <svc>        重启服务（kill 后重新启动）
#   systemctl enable <svc>         开机启动（enable + bootstrap 加载）
#   systemctl disable <svc>        取消开机启动（disable + bootout 卸载）

if [[ "$OSTYPE" == darwin* ]]; then

systemctl() {
    emulate -L zsh
    setopt local_options unset

    local cmd="${1:-}"
    local svc="${2:-}"

    # --- usage ---
    if [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" ]]; then
        print -- "Usage: systemctl <command> [service]"
        print -- ""
        print -- "Commands:"
        print -- "  list                  列出第三方服务（过滤 com.apple.*）"
        print -- "  status <svc>          查看服务状态（支持模糊匹配）"
        print -- "  start <svc>           启动服务"
        print -- "  stop <svc>            停止服务（SIGTERM）"
        print -- "  restart <svc>         重启服务"
        print -- "  enable <svc>          开机启动（enable + bootstrap）"
        print -- "  disable <svc>         取消开机启动（disable + bootout）"
        print -- "  cat <svc>             显示 plist 文件内容"
        print -- "  edit <svc>            编辑 plist 文件（vim，无则降级 TextEdit）"
        print -- "  logs <svc> [-f]       查看日志（-f 实时跟踪，仅文件日志有效）"
        print -- ""
        print -- "服务名支持模糊匹配：'openresty' 可匹配 'homebrew.mxcl.openresty'"
        return 0
    fi

    # --- 颜色定义 ---
    # 交互式终端上色，管道/重定向时降级为无色（避免转义码污染日志）
    if [[ -t 1 ]]; then
        local C_GREEN=$'\033[32m' C_RED=$'\033[31m' C_YELLOW=$'\033[33m' C_RESET=$'\033[0m'
    else
        local C_GREEN='' C_RED='' C_YELLOW='' C_RESET=''
    fi

    local uid=$(id -u)
    local user_domain="gui/$uid"

    # --- 内部函数：模糊匹配 label ---
    # 输入用户给的服务名，输出完整 label。匹配失败返回非零。
    _systemctl_resolve_label() {
        local input="$1"
        # 拒绝 com.apple.* 系统服务
        if [[ "$input" == com.apple.* ]]; then
            print -u2 -- "systemctl: 拒绝操作系统服务: $input"
            return 1
        fi

        # 1. 精确匹配：先看用户域是否已加载
        if launchctl print "$user_domain/$input" >/dev/null 2>&1; then
            print -- "$input"
            return 0
        fi

        # 2. 模糊匹配：在 list 里 grep
        local matches=()
        while IFS= read -r line; do
            # list 格式: "PID  Status  Label"
            local label="${line##*	}"  # 取最后一个 tab 后的内容
            [[ "$label" == com.apple.* ]] && continue
            [[ "$label" == application.* ]] && continue
            if [[ "$label" == *"$input"* ]]; then
                matches+=("$label")
            fi
        done < <(launchctl list 2>/dev/null)

        # 也搜 plist 文件名（服务未加载时 list 里没有）
        local plist_label
        for f in ~/Library/LaunchAgents/*.plist /Library/LaunchAgents/*.plist; do
            [[ -f "$f" ]] || continue
            plist_label="${f:t:r}"  # 文件名去扩展名
            [[ "$plist_label" == com.apple.* ]] && continue
            if [[ "$plist_label" == *"$input"* ]] && (( ! ${matches[(I)$plist_label]} )); then
                matches+=("$plist_label")
            fi
        done

        if (( ${#matches[@]} == 0 )); then
            print -u2 -- "systemctl: 未找到匹配 '$input' 的服务"
            return 1
        elif (( ${#matches[@]} == 1 )); then
            print -- "${matches[1]}"
            return 0
        else
            print -u2 -- "systemctl: '$input' 匹配到多个服务，请细化："
            local m
            for m in "${matches[@]}"; do
                print -u2 -- "  $m"
            done
            return 1
        fi
    }

    # --- 内部函数：查找 plist 文件路径 ---
    _systemctl_find_plist() {
        local label="$1"
        # 用户域
        if [[ -f "$HOME/Library/LaunchAgents/${label}.plist" ]]; then
            print -- "$HOME/Library/LaunchAgents/${label}.plist"
            return 0
        fi
        # 系统域（需要 sudo）
        if [[ -f "/Library/LaunchDaemons/${label}.plist" ]]; then
            print -- "/Library/LaunchDaemons/${label}.plist"
            return 2  # 返回 2 表示系统域，调用方据此加 sudo
        fi
        return 1
    }

    # --- 内部函数：判断服务在哪个域 ---
    # 返回 "user" 或 "system"
    _systemctl_detect_domain() {
        local label="$1"
        # 用户域能 print 就是用户域
        if launchctl print "$user_domain/$label" >/dev/null 2>&1; then
            print -- "user"
            return 0
        fi
        # 系统域
        if launchctl print "system/$label" >/dev/null 2>&1; then
            print -- "system"
            return 0
        fi
        # 未加载，看 plist 在哪
        local plist_result
        _systemctl_find_plist "$label" >/dev/null 2>&1 && return $?
        # 默认当用户域
        print -- "user"
        return 0
    }

    # --- list ---
    if [[ "$cmd" == "list" ]]; then
        print -- "PID        Status  Label"
        launchctl list 2>/dev/null | awk -F'\t' '
        NR == 1 { next }
        $3 !~ /^com\.apple\./ && $3 !~ /^application\./ { printf "%-10s %-7s %s\n", $1, $2, $3 }
        '
        return 0
    fi

    # --- 以下命令都需要 service 参数 ---
    if [[ -z "$svc" ]]; then
        print -u2 -- "systemctl: '$cmd' 需要服务名参数"
        print -u2 -- "用法: systemctl $cmd <service>"
        return 1
    fi

    # 模糊匹配
    local label
    if ! label=$(_systemctl_resolve_label "$svc"); then
        return 1
    fi

    # 探测域
    local domain_type
    domain_type=$(_systemctl_detect_domain "$label")
    local target_domain
    local sudo_prefix=""
    if [[ "$domain_type" == "system" ]]; then
        target_domain="system"
        sudo_prefix="sudo"
        print -u2 -- "systemctl: $label 在系统域，需要 sudo"
    else
        target_domain="$user_domain"
    fi
    local service_target="$target_domain/$label"

    # --- status ---
    if [[ "$cmd" == "status" ]]; then
        local print_out pid status_line runs loaded_path job_state
        print_out=$(launchctl print "$service_target" 2>&1)
        if [[ $? -ne 0 ]]; then
            # 未加载：黄色
            print -- "${C_YELLOW}●${C_RESET} $label"
            print -- "   Loaded: not loaded (服务未运行)"
            print -- "   Active: ${C_YELLOW}inactive (dead)${C_RESET}"
            # 检查是否 disabled
            local dis
            dis=$(launchctl print-disabled "$target_domain" 2>/dev/null | grep "\"$label\"" | sed 's/.*=> //')
            [[ -n "$dis" ]] && print -- "   Enabled: $dis"
            return 0
        fi

        # 从 list 取 PID 和 status
        local list_line
        list_line=$(launchctl list 2>/dev/null | awk -F'\t' -v lbl="$label" '$3 == lbl')
        pid="${list_line%%$'\t'*}"
        pid="${pid// /}"

        # 从 print 解析关键字段
        loaded_path=$(print -- "$print_out" | grep -E '^\s+path = ' | head -1 | sed 's/.*path = //')
        job_state=$(print -- "$print_out" | grep -E '^\s+job state = ' | head -1 | sed 's/.*job state = //')
        runs=$(print -- "$print_out" | grep -E '^\s+runs = ' | head -1 | sed 's/.*runs = //')

        # enabled 状态
        local enabled_state
        enabled_state=$(launchctl print-disabled "$target_domain" 2>/dev/null | grep "\"$label\"" | sed 's/.*=> //')
        [[ -z "$enabled_state" ]] && enabled_state="enabled"

        # 活动状态判断 + 颜色分级
        # 绿色=running，红色=spawn failed 等错误，黄色=exited/dead 未运行
        local active_str active_color dot_color
        if [[ -n "$pid" && "$pid" != "-" ]]; then
            active_str="active (running)"
            active_color="$C_GREEN"
            dot_color="$C_GREEN"
        elif [[ "$job_state" == "running" ]]; then
            active_str="active (running)"
            active_color="$C_GREEN"
            dot_color="$C_GREEN"
        elif [[ "$job_state" == "exited" ]]; then
            active_str="inactive (dead)"
            active_color="$C_YELLOW"
            dot_color="$C_YELLOW"
        elif [[ "$job_state" == "spawn failed" || "$job_state" == *"failed"* ]]; then
            active_str="inactive ($job_state)"
            active_color="$C_RED"
            dot_color="$C_RED"
        else
            active_str="inactive ($job_state)"
            active_color="$C_YELLOW"
            dot_color="$C_YELLOW"
        fi

        print -- "${dot_color}●${C_RESET} $label"
        if [[ -n "$loaded_path" ]]; then
            print -- "   Loaded: loaded ($loaded_path)"
        else
            print -- "   Loaded: loaded"
        fi
        print -- "   Active: ${active_color}${active_str}${C_RESET}"
        print -- "   Enabled: $enabled_state"
        print -- "   PID: ${pid:--}     Runs: ${runs:--}     Job State: ${job_state:--}"
        return 0
    fi

    # --- start ---
    if [[ "$cmd" == "start" ]]; then
        $sudo_prefix launchctl kickstart "$service_target"
        return $?
    fi

    # --- stop ---
    if [[ "$cmd" == "stop" ]]; then
        $sudo_prefix launchctl kill SIGTERM "$service_target"
        return $?
    fi

    # --- restart ---
    if [[ "$cmd" == "restart" ]]; then
        $sudo_prefix launchctl kickstart -k "$service_target"
        return $?
    fi

    # --- enable ---
    if [[ "$cmd" == "enable" ]]; then
        # enable 只改标志位，还要 bootstrap 加载
        $sudo_prefix launchctl enable "$service_target"
        local plist_path plist_rc
        plist_path=$(_systemctl_find_plist "$label")
        plist_rc=$?
        if [[ $plist_rc -ne 0 && -z "$plist_path" ]]; then
            print -u2 -- "systemctl: 找不到 $label 的 plist 文件"
            return 1
        fi
        if [[ $plist_rc -eq 2 ]]; then
            print -u2 -- "systemctl: 系统域 plist，需要 sudo"
        fi
        $sudo_prefix launchctl bootstrap "$target_domain" "$plist_path"
        local rc=$?
        if [[ $rc -eq 0 ]]; then
            print -- "✅ $label 已启用（开机启动）"
        fi
        return $rc
    fi

    # --- disable ---
    if [[ "$cmd" == "disable" ]]; then
        # bootout 卸载，disable 改标志位
        $sudo_prefix launchctl bootout "$service_target" 2>/dev/null || true
        $sudo_prefix launchctl disable "$service_target"
        local rc=$?
        if [[ $rc -eq 0 ]]; then
            print -- "✅ $label 已禁用（取消开机启动）"
        fi
        return $rc
    fi

    # --- cat：显示 plist 文件内容（bat 高亮，无则降级 cat）---
    if [[ "$cmd" == "cat" ]]; then
        local plist_path plist_rc
        plist_path=$(_systemctl_find_plist "$label")
        plist_rc=$?
        if [[ -z "$plist_path" ]]; then
            print -u2 -- "systemctl: 找不到 $label 的 plist 文件"
            return 1
        fi
        print -- "# $plist_path"
        # bat 高亮（plist 本质是 XML），无 bat 降级 cat
        if [[ $plist_rc -eq 2 ]]; then
            if command -v bat >/dev/null 2>&1; then
                sudo bat --language xml --style plain --paging never "$plist_path"
            else
                sudo cat "$plist_path"
            fi
        else
            if command -v bat >/dev/null 2>&1; then
                bat --language xml --style plain --paging never "$plist_path"
            else
                cat "$plist_path"
            fi
        fi
        return $?
    fi

    # --- edit：编辑 plist 文件 ---
    if [[ "$cmd" == "edit" ]]; then
        local plist_path plist_rc
        plist_path=$(_systemctl_find_plist "$label")
        plist_rc=$?
        if [[ -z "$plist_path" ]]; then
            print -u2 -- "systemctl: 找不到 $label 的 plist 文件"
            return 1
        fi
        # vim 优先，无则降级 nano，再无则 TextEdit
        if command -v vim >/dev/null 2>&1; then
            local editor=vim
        elif command -v nano >/dev/null 2>&1; then
            local editor=nano
            print -u2 -- "systemctl: 未找到 vim，降级使用 nano"
        else
            local editor=""
        fi
        if [[ -n "$editor" ]]; then
            if [[ $plist_rc -eq 2 ]]; then
                sudo "$editor" "$plist_path"
            else
                "$editor" "$plist_path"
            fi
        else
            # 最后降级：TextEdit（GUI）
            print -u2 -- "systemctl: 未找到 vim/nano，降级使用 TextEdit"
            open -a TextEdit "$plist_path"
        fi
        return $?
    fi

    # --- logs：查看服务日志 ---
    # 优先级：plist 的 StandardOutPath/ErrorPath 文件 > unified logging
    if [[ "$cmd" == "logs" ]]; then
        local follow="${3:-}"
        local plist_path plist_rc
        plist_path=$(_systemctl_find_plist "$label")
        plist_rc=$?
        if [[ -z "$plist_path" ]]; then
            print -u2 -- "systemctl: 找不到 $label 的 plist 文件，无法查询日志配置"
            return 1
        fi

        # 从 plist 提取 StandardOutPath / StandardErrorPath
        local log_files=()
        local out_path err_path
        # 用 plutil 转换后 grep，兼容二进制/文本 plist
        out_path=$(plutil -extract StandardOutPath raw "$plist_path" 2>/dev/null) && \
            [[ -n "$out_path" ]] && log_files+=("$out_path")
        err_path=$(plutil -extract StandardErrorPath raw "$plist_path" 2>/dev/null) && \
            [[ -n "$err_path" ]] && (( ! ${log_files[(I)$err_path]} )) && log_files+=("$err_path")

        if (( ${#log_files[@]} > 0 )); then
            # 路线 A：有日志文件
            if [[ "$follow" == "-f" ]]; then
                print -- "实时跟踪: ${log_files[1]}（Ctrl-C 退出）"
                tail -f "${log_files[@]}"
            else
                local lf
                for lf in "${log_files[@]}"; do
                    print -- "=== $lf ==="
                    if [[ -f "$lf" ]]; then
                        tail -n 100 "$lf"
                        [[ $(wc -l < "$lf") -gt 100 ]] && print -- "...（仅显示最后 100 行，完整日志: $lf）"
                    else
                        print -- "  （文件不存在）"
                    fi
                done
            fi
        else
            # 路线 B：无日志文件，回退 unified logging
            if [[ "$follow" == "-f" ]]; then
                print -- "该服务未配置日志文件，实时跟踪 launchd 事件日志（Ctrl-C 退出）"
                print -- "（注：这是 launchd 的 spawn/exit 事件，非服务自身输出）"
                /usr/bin/log stream --predicate "eventMessage CONTAINS '$label'" --style compact
            else
                print -- "该服务未配置 StandardOutPath/ErrorPath，回退到 unified logging（launchd 事件日志）："
                print -- ""
                /usr/bin/log show --predicate "eventMessage CONTAINS '$label'" --last 30m --style compact 2>&1 | tail -n 100
                print -- ""
                print -- "（注：这是 launchd 的 spawn/exit 事件，非服务自身 stdout/stderr）"
            fi
        fi
        return 0
    fi

    # --- 未知命令 ---
    print -u2 -- "systemctl: 未知命令 '$cmd'"
    print -u2 -- "可用命令: list status start stop restart enable disable cat edit logs"
    return 1
}

# Linux / 其他平台：不定义 systemctl 函数，使用系统原生 systemctl
# 此处无需任何代码

fi