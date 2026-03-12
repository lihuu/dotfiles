#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew

if ! docker_available; then
  die "当前 Docker 环境不可用，无法从 native 迁移到 docker"
fi

mode="$(current_install_mode)"
if [[ "${mode}" == "docker" ]]; then
  log_info "当前已经是 docker 安装模式，无需迁移"
  exit 0
fi

log_info "开始从 native 安装迁移到 docker 安装"
log_info "先准备 docker 栈和宿主机 node_exporter"
install_docker_stack

log_info "停止并移除 native 三件套"
remove_native_stack

log_info "启动 docker 版 Prometheus / Alertmanager / Grafana"
start_docker_stack

log_success "迁移完成，当前模式已切换为 docker"
