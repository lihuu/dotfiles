#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew

log_info "使用 Homebrew 前缀: ${HOMEBREW_PREFIX}"
log_info "开始安装 Prometheus / node_exporter / Alertmanager / Grafana"

brew install prometheus
brew install node_exporter
brew install grafana

set +e
brew install alertmanager
alertmanager_install_rc=$?
set -e

if [[ ${alertmanager_install_rc} -ne 0 ]]; then
  log_warn "未找到 core 版 alertmanager，改用仓库内置 Homebrew tap"
  if ! brew tap | grep -q '^local/monitoring$'; then
    brew tap-new local/monitoring
  fi
  mkdir -p "$(brew --repository)/Library/Taps/local/homebrew-monitoring/Formula"
  cp "${SCRIPT_DIR}/Formula/alertmanager.rb" "$(brew --repository)/Library/Taps/local/homebrew-monitoring/Formula/alertmanager.rb"
  brew install local/monitoring/alertmanager
fi

ensure_homebrew_dirs
sync_rendered_configs

log_success "软件安装和配置同步完成"
log_info "下一步运行: ${SCRIPT_DIR}/start.sh"
