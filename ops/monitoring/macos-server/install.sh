#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew

mode="$(resolve_install_mode)"
log_info "安装模式: ${mode}"

case "${mode}" in
  docker)
    install_docker_stack
    ;;
  native)
    install_native_stack
    ;;
esac

log_info "下一步运行: ${SCRIPT_DIR}/start.sh"
