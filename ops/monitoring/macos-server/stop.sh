#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew

log_info "停止 brew services"
brew services stop grafana || true
brew services stop alertmanager || true
brew services stop prometheus || true
brew services stop node_exporter || true

log_success "停止命令已执行"
