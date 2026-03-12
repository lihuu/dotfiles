#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

mode="${1:-all}"

case "${mode}" in
  all)
    ensure_rendered_configs
    ;;
  docker|native)
    render_mode_configs "${mode}"
    ;;
  *)
    die "render-configs.sh 仅支持 all / docker / native，收到: ${mode}"
    ;;
esac

log_success "已渲染配置到 ${RENDER_DIR}"
