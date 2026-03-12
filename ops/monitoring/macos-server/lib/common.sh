#!/usr/bin/env bash

COLOR_RED=$'\033[31m'
COLOR_GREEN=$'\033[32m'
COLOR_YELLOW=$'\033[33m'
COLOR_BLUE=$'\033[34m'
COLOR_RESET=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RENDER_DIR="${SCRIPT_DIR}/.rendered"

log_info() {
  printf "%s[INFO]%s %s\n" "${COLOR_BLUE}" "${COLOR_RESET}" "$*"
}

log_warn() {
  printf "%s[WARN]%s %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$*"
}

log_error() {
  printf "%s[ERROR]%s %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2
}

log_success() {
  printf "%s[OK]%s %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$*"
}

die() {
  log_error "$*"
  exit 1
}

require_command() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 || die "缺少命令: ${command_name}"
}

load_env() {
  if [[ -f "${SCRIPT_DIR}/env.example" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/env.example"
    set +a
  fi

  if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/.env"
    set +a
  fi
}

detect_brew_prefix() {
  if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    printf "%s" "${HOMEBREW_PREFIX}"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    brew --prefix
    return
  fi

  if [[ "$(uname -m)" == "arm64" ]]; then
    printf "/opt/homebrew"
  else
    printf "/usr/local"
  fi
}

apply_defaults() {
  export HOMEBREW_PREFIX
  HOMEBREW_PREFIX="$(detect_brew_prefix)"

  export PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
  export NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
  export ALERTMANAGER_PORT="${ALERTMANAGER_PORT:-9093}"
  export GRAFANA_PORT="${GRAFANA_PORT:-3000}"

  export PROMETHEUS_LISTEN_ADDRESS="${PROMETHEUS_LISTEN_ADDRESS:-127.0.0.1}"
  export NODE_EXPORTER_LISTEN_ADDRESS="${NODE_EXPORTER_LISTEN_ADDRESS:-127.0.0.1}"
  export ALERTMANAGER_LISTEN_ADDRESS="${ALERTMANAGER_LISTEN_ADDRESS:-127.0.0.1}"
  export GRAFANA_LISTEN_ADDRESS="${GRAFANA_LISTEN_ADDRESS:-127.0.0.1}"

  export PROMETHEUS_SCRAPE_INTERVAL="${PROMETHEUS_SCRAPE_INTERVAL:-15s}"
  export PROMETHEUS_EVALUATION_INTERVAL="${PROMETHEUS_EVALUATION_INTERVAL:-15s}"
  export PROMETHEUS_RETENTION_TIME="${PROMETHEUS_RETENTION_TIME:-15d}"

  export CPU_ALERT_THRESHOLD="${CPU_ALERT_THRESHOLD:-80}"
  export MEM_ALERT_THRESHOLD="${MEM_ALERT_THRESHOLD:-85}"
  export DISK_ALERT_THRESHOLD="${DISK_ALERT_THRESHOLD:-15}"

  export GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
  export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"

  export ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
  export TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  export TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

  export PROMETHEUS_STORAGE_PATH="${PROMETHEUS_STORAGE_PATH:-${HOMEBREW_PREFIX}/var/prometheus}"
  export ALERTMANAGER_STORAGE_PATH="${ALERTMANAGER_STORAGE_PATH:-${HOMEBREW_PREFIX}/var/lib/alertmanager}"
  export GRAFANA_DATA_PATH="${GRAFANA_DATA_PATH:-${HOMEBREW_PREFIX}/var/lib/grafana}"
  export GRAFANA_LOG_PATH="${GRAFANA_LOG_PATH:-${HOMEBREW_PREFIX}/var/log/grafana}"
  export GRAFANA_DASHBOARDS_DEST="${GRAFANA_DASHBOARDS_DEST:-${GRAFANA_DATA_PATH}/dashboards}"
  export TEXTFILE_COLLECTOR_DIR="${TEXTFILE_COLLECTOR_DIR:-${HOMEBREW_PREFIX}/var/lib/node_exporter/textfile_collector}"

  export PROMETHEUS_CONFIG_DEST="${HOMEBREW_PREFIX}/etc/prometheus.yml"
  export PROMETHEUS_RULES_DEST="${HOMEBREW_PREFIX}/etc/alert.rules.yml"
  export PROMETHEUS_ARGS_DEST="${HOMEBREW_PREFIX}/etc/prometheus.args"
  export NODE_EXPORTER_ARGS_DEST="${HOMEBREW_PREFIX}/etc/node_exporter.args"
  export ALERTMANAGER_CONFIG_DEST="${HOMEBREW_PREFIX}/etc/alertmanager.yml"
  export ALERTMANAGER_ARGS_DEST="${HOMEBREW_PREFIX}/etc/alertmanager.args"
  export GRAFANA_CONFIG_DEST="${HOMEBREW_PREFIX}/etc/grafana/grafana.ini"
  export GRAFANA_PROVISIONING_DEST="${HOMEBREW_PREFIX}/etc/grafana/provisioning"
  export GRAFANA_DATASOURCE_DEST="${GRAFANA_PROVISIONING_DEST}/datasources/prometheus.yml"
  export GRAFANA_DASHBOARD_PROVIDER_DEST="${GRAFANA_PROVISIONING_DEST}/dashboards/dashboards.yml"

  export MONITORED_HOSTNAME="${MONITORED_HOSTNAME:-$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || hostname)}"
}

ensure_render_dir() {
  mkdir -p "${RENDER_DIR}"
}

ensure_homebrew_dirs() {
  mkdir -p "${HOMEBREW_PREFIX}/etc/grafana/provisioning/datasources"
  mkdir -p "${HOMEBREW_PREFIX}/etc/grafana/provisioning/dashboards"
  mkdir -p "${PROMETHEUS_STORAGE_PATH}"
  mkdir -p "${ALERTMANAGER_STORAGE_PATH}"
  mkdir -p "${GRAFANA_DATA_PATH}"
  mkdir -p "${GRAFANA_LOG_PATH}"
  mkdir -p "${GRAFANA_DASHBOARDS_DEST}"
  mkdir -p "${TEXTFILE_COLLECTOR_DIR}"
}

render_template() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "${dest}")"
  perl -pe 's/\$\{([A-Z0-9_]+)\}/exists $ENV{$1} ? $ENV{$1} : ""/ge' "${src}" > "${dest}"
}

ensure_backup_root() {
  if [[ -z "${BACKUP_ROOT:-}" ]]; then
    BACKUP_ROOT="${SCRIPT_DIR}/backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${BACKUP_ROOT}"
  fi
}

sync_with_backup() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "${dest}")"

  if [[ -f "${dest}" ]] && ! cmp -s "${src}" "${dest}"; then
    ensure_backup_root
    local backup_dest="${BACKUP_ROOT}${dest}"
    mkdir -p "$(dirname "${backup_dest}")"
    cp "${dest}" "${backup_dest}"
    log_warn "已备份现有文件: ${dest} -> ${backup_dest}"
  fi

  cp "${src}" "${dest}"
}

ensure_rendered_configs() {
  "${SCRIPT_DIR}/render-configs.sh" >/dev/null
}

sync_rendered_configs() {
  ensure_rendered_configs
  ensure_homebrew_dirs

  sync_with_backup "${RENDER_DIR}/prometheus.yml" "${PROMETHEUS_CONFIG_DEST}"
  sync_with_backup "${RENDER_DIR}/alert.rules.yml" "${PROMETHEUS_RULES_DEST}"
  sync_with_backup "${RENDER_DIR}/prometheus.args" "${PROMETHEUS_ARGS_DEST}"
  sync_with_backup "${RENDER_DIR}/node_exporter.args" "${NODE_EXPORTER_ARGS_DEST}"
  sync_with_backup "${RENDER_DIR}/alertmanager.yml" "${ALERTMANAGER_CONFIG_DEST}"
  sync_with_backup "${RENDER_DIR}/alertmanager.args" "${ALERTMANAGER_ARGS_DEST}"
  sync_with_backup "${RENDER_DIR}/grafana.ini" "${GRAFANA_CONFIG_DEST}"
  sync_with_backup "${RENDER_DIR}/grafana-provisioning/datasources/prometheus.yml" "${GRAFANA_DATASOURCE_DEST}"
  sync_with_backup "${RENDER_DIR}/grafana-provisioning/dashboards/dashboards.yml" "${GRAFANA_DASHBOARD_PROVIDER_DEST}"
  sync_with_backup "${SCRIPT_DIR}/dashboards/macos-self-monitoring.json" "${GRAFANA_DASHBOARDS_DEST}/macos-self-monitoring.json"
}

print_healthcheck_urls() {
  cat <<EOF
Prometheus:
  http://${PROMETHEUS_LISTEN_ADDRESS}:${PROMETHEUS_PORT}/-/healthy
  http://${PROMETHEUS_LISTEN_ADDRESS}:${PROMETHEUS_PORT}/api/v1/targets
node_exporter:
  http://${NODE_EXPORTER_LISTEN_ADDRESS}:${NODE_EXPORTER_PORT}/metrics
Alertmanager:
  http://${ALERTMANAGER_LISTEN_ADDRESS}:${ALERTMANAGER_PORT}/-/healthy
  http://${ALERTMANAGER_LISTEN_ADDRESS}:${ALERTMANAGER_PORT}/api/v2/status
Grafana:
  http://${GRAFANA_LISTEN_ADDRESS}:${GRAFANA_PORT}/api/health
EOF
}

show_port_status() {
  local port="$1"
  if lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN
  else
    printf "port %s 未监听\n" "${port}"
  fi
}
