#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

mode="$(current_install_mode)"
log_info "当前安装模式: ${mode}"

case "${mode}" in
  docker)
    start_docker_stack
    ;;
  native)
    start_native_stack
    ;;
  *)
    die "未知安装模式: ${mode}"
    ;;
esac

log_success "启动完成，开始输出状态"
"${SCRIPT_DIR}/status.sh"
