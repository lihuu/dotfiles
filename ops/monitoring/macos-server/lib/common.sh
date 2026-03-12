#!/usr/bin/env bash

COLOR_RED=$'\033[31m'
COLOR_GREEN=$'\033[32m'
COLOR_YELLOW=$'\033[33m'
COLOR_BLUE=$'\033[34m'
COLOR_RESET=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RENDER_DIR="${SCRIPT_DIR}/.rendered"
DATA_DIR="${SCRIPT_DIR}/data"

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

  export STACK_BIND_ADDRESS="${STACK_BIND_ADDRESS:-0.0.0.0}"
  export PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
  export NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
  export ALERTMANAGER_PORT="${ALERTMANAGER_PORT:-9093}"
  export GRAFANA_PORT="${GRAFANA_PORT:-3000}"

  export NODE_EXPORTER_LISTEN_ADDRESS="${NODE_EXPORTER_LISTEN_ADDRESS:-0.0.0.0}"
  export LOCAL_STATUS_HOST="${LOCAL_STATUS_HOST:-127.0.0.1}"

  export PROMETHEUS_SCRAPE_INTERVAL="${PROMETHEUS_SCRAPE_INTERVAL:-15s}"
  export PROMETHEUS_EVALUATION_INTERVAL="${PROMETHEUS_EVALUATION_INTERVAL:-15s}"
  export PROMETHEUS_RETENTION_TIME="${PROMETHEUS_RETENTION_TIME:-7d}"
  export PROMETHEUS_RETENTION_SIZE="${PROMETHEUS_RETENTION_SIZE:-8GB}"

  export CPU_ALERT_THRESHOLD="${CPU_ALERT_THRESHOLD:-80}"
  export MEM_ALERT_THRESHOLD="${MEM_ALERT_THRESHOLD:-85}"
  export DISK_ALERT_THRESHOLD="${DISK_ALERT_THRESHOLD:-15}"

  export GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
  export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"

  export ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
  export TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  export TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

  export TEXTFILE_COLLECTOR_DIR="${TEXTFILE_COLLECTOR_DIR:-${HOMEBREW_PREFIX}/var/lib/node_exporter/textfile_collector}"

  export NODE_EXPORTER_ARGS_DEST="${HOMEBREW_PREFIX}/etc/node_exporter.args"

  export PROMETHEUS_IMAGE="${PROMETHEUS_IMAGE:-prom/prometheus:v3.10.0}"
  export ALERTMANAGER_IMAGE="${ALERTMANAGER_IMAGE:-prom/alertmanager:v0.31.1}"
  export GRAFANA_IMAGE="${GRAFANA_IMAGE:-grafana/grafana:12.4.0}"
  export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-macos-monitoring}"
  export COMPOSE_ENV_FILE="${SCRIPT_DIR}/.env"
  if [[ ! -f "${COMPOSE_ENV_FILE}" ]]; then
    export COMPOSE_ENV_FILE="${SCRIPT_DIR}/env.example"
  fi

  export MONITORED_HOSTNAME="${MONITORED_HOSTNAME:-$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || hostname)}"
}

ensure_render_dir() {
  mkdir -p "${RENDER_DIR}"
}

ensure_data_dirs() {
  mkdir -p "${DATA_DIR}/prometheus"
  mkdir -p "${DATA_DIR}/alertmanager"
  mkdir -p "${DATA_DIR}/grafana"
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

sync_node_exporter_config() {
  ensure_rendered_configs
  ensure_data_dirs
  sync_with_backup "${RENDER_DIR}/node_exporter.args" "${NODE_EXPORTER_ARGS_DEST}"
}

docker_compose() {
  (
    cd "${SCRIPT_DIR}"
    docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${COMPOSE_ENV_FILE}" "$@"
  )
}

remove_path_if_exists() {
  local target="$1"
  if [[ -e "${target}" ]]; then
    rm -rf "${target}"
    log_warn "已删除旧文件/目录: ${target}"
  fi
}

remove_legacy_brew_stack() {
  brew services stop grafana >/dev/null 2>&1 || true
  brew services stop alertmanager >/dev/null 2>&1 || true
  brew services stop prometheus >/dev/null 2>&1 || true

  if brew list --versions grafana >/dev/null 2>&1; then
    brew uninstall grafana
  fi

  if brew list --versions alertmanager >/dev/null 2>&1; then
    brew uninstall alertmanager
  fi

  if brew list --versions prometheus >/dev/null 2>&1; then
    brew uninstall prometheus
  fi

  if brew tap | grep -q '^local/monitoring$'; then
    brew untap local/monitoring || true
  fi

  remove_path_if_exists "${HOMEBREW_PREFIX}/etc/prometheus.yml"
  remove_path_if_exists "${HOMEBREW_PREFIX}/etc/alert.rules.yml"
  remove_path_if_exists "${HOMEBREW_PREFIX}/etc/prometheus.args"
  remove_path_if_exists "${HOMEBREW_PREFIX}/etc/alertmanager.yml"
  remove_path_if_exists "${HOMEBREW_PREFIX}/etc/alertmanager.args"
  remove_path_if_exists "${HOMEBREW_PREFIX}/etc/grafana/grafana.ini"
  remove_path_if_exists "${HOMEBREW_PREFIX}/etc/grafana/provisioning/datasources/prometheus.yml"
  remove_path_if_exists "${HOMEBREW_PREFIX}/etc/grafana/provisioning/dashboards/dashboards.yml"
  remove_path_if_exists "${HOMEBREW_PREFIX}/var/prometheus"
  remove_path_if_exists "${HOMEBREW_PREFIX}/var/lib/alertmanager"
  remove_path_if_exists "${HOMEBREW_PREFIX}/var/lib/grafana"
  remove_path_if_exists "${HOMEBREW_PREFIX}/var/log/grafana"
}

print_healthcheck_urls() {
  cat <<EOF
Prometheus:
  http://${LOCAL_STATUS_HOST}:${PROMETHEUS_PORT}/-/healthy
  http://${LOCAL_STATUS_HOST}:${PROMETHEUS_PORT}/api/v1/targets
node_exporter:
  http://${LOCAL_STATUS_HOST}:${NODE_EXPORTER_PORT}/metrics
Alertmanager:
  http://${LOCAL_STATUS_HOST}:${ALERTMANAGER_PORT}/-/healthy
  http://${LOCAL_STATUS_HOST}:${ALERTMANAGER_PORT}/api/v2/status
Grafana:
  http://${LOCAL_STATUS_HOST}:${GRAFANA_PORT}/api/health
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
