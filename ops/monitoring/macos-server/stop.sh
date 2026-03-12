#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew
require_command docker

log_info "停止 docker compose 中的 Prometheus / Alertmanager / Grafana"
docker_compose down || true

log_info "停止宿主机 node_exporter"
brew services stop node_exporter || true

log_success "停止命令已执行"
