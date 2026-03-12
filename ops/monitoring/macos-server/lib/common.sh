#!/usr/bin/env bash

COLOR_RED=$'\033[31m'
COLOR_GREEN=$'\033[32m'
COLOR_YELLOW=$'\033[33m'
COLOR_BLUE=$'\033[34m'
COLOR_RESET=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RENDER_DIR="${SCRIPT_DIR}/.rendered"
DATA_DIR="${SCRIPT_DIR}/data"
INSTALL_MODE_FILE="${SCRIPT_DIR}/.install-mode"

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

  export INSTALL_MODE="${INSTALL_MODE:-auto}"
  export LOCAL_STATUS_HOST="${LOCAL_STATUS_HOST:-127.0.0.1}"
  export PROMETHEUS_BIND_ADDRESS="${PROMETHEUS_BIND_ADDRESS:-127.0.0.1}"
  export ALERTMANAGER_BIND_ADDRESS="${ALERTMANAGER_BIND_ADDRESS:-127.0.0.1}"
  export GRAFANA_BIND_ADDRESS="${GRAFANA_BIND_ADDRESS:-0.0.0.0}"

  export PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
  export NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
  export ALERTMANAGER_PORT="${ALERTMANAGER_PORT:-9093}"
  export GRAFANA_PORT="${GRAFANA_PORT:-3000}"

  export NODE_EXPORTER_LISTEN_ADDRESS="${NODE_EXPORTER_LISTEN_ADDRESS:-0.0.0.0}"

  export PROMETHEUS_SCRAPE_INTERVAL="${PROMETHEUS_SCRAPE_INTERVAL:-15s}"
  export PROMETHEUS_EVALUATION_INTERVAL="${PROMETHEUS_EVALUATION_INTERVAL:-15s}"
  export PROMETHEUS_RETENTION_TIME="${PROMETHEUS_RETENTION_TIME:-7d}"
  export PROMETHEUS_RETENTION_SIZE="${PROMETHEUS_RETENTION_SIZE:-8GB}"

  export CPU_ALERT_THRESHOLD="${CPU_ALERT_THRESHOLD:-80}"
  export MEM_ALERT_THRESHOLD="${MEM_ALERT_THRESHOLD:-85}"
  export DISK_ALERT_THRESHOLD="${DISK_ALERT_THRESHOLD:-15}"

  export GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
  export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"

  export TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  export TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
  export BARK_SERVER_URL="${BARK_SERVER_URL:-https://api.day.app}"
  export BARK_DEVICE_KEY="${BARK_DEVICE_KEY:-}"
  export BARK_GROUP="${BARK_GROUP:-Prometheus Alerts}"
  export BARK_SOUND="${BARK_SOUND:-}"
  export BARK_ICON="${BARK_ICON:-}"
  export BARK_URL="${BARK_URL:-}"
  export BARK_LEVEL="${BARK_LEVEL:-active}"
  export BARK_AUTOMATIC_COPY="${BARK_AUTOMATIC_COPY:-0}"
  export BARK_IS_ARCHIVE="${BARK_IS_ARCHIVE:-1}"
  export BARK_BRIDGE_PORT="${BARK_BRIDGE_PORT:-18080}"
  export BARK_BRIDGE_BIND_ADDRESS="${BARK_BRIDGE_BIND_ADDRESS:-127.0.0.1}"
  export BARK_BRIDGE_PID_FILE="${BARK_BRIDGE_PID_FILE:-${DATA_DIR}/bark-bridge.pid}"
  export BARK_BRIDGE_LOG_FILE="${BARK_BRIDGE_LOG_FILE:-${DATA_DIR}/bark-bridge.log}"

  export TEXTFILE_COLLECTOR_DIR="${TEXTFILE_COLLECTOR_DIR:-${HOMEBREW_PREFIX}/var/lib/node_exporter/textfile_collector}"

  export PROMETHEUS_STORAGE_PATH="${PROMETHEUS_STORAGE_PATH:-${HOMEBREW_PREFIX}/var/prometheus}"
  export ALERTMANAGER_STORAGE_PATH="${ALERTMANAGER_STORAGE_PATH:-${HOMEBREW_PREFIX}/var/lib/alertmanager}"
  export GRAFANA_DATA_PATH="${GRAFANA_DATA_PATH:-${HOMEBREW_PREFIX}/var/lib/grafana}"
  export GRAFANA_LOG_PATH="${GRAFANA_LOG_PATH:-${HOMEBREW_PREFIX}/var/log/grafana}"
  export GRAFANA_DASHBOARDS_DEST="${GRAFANA_DASHBOARDS_DEST:-${GRAFANA_DATA_PATH}/dashboards}"

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

docker_available() {
  command -v docker >/dev/null 2>&1 &&
    docker compose version >/dev/null 2>&1 &&
    docker info >/dev/null 2>&1
}

resolve_install_mode() {
  local requested="${1:-${INSTALL_MODE:-auto}}"

  case "${requested}" in
    docker|native)
      printf "%s" "${requested}"
      ;;
    auto)
      if docker_available; then
        printf "docker"
      else
        printf "native"
      fi
      ;;
    *)
      die "不支持的安装模式: ${requested}，可选值为 auto / docker / native"
      ;;
  esac
}

persist_install_mode() {
  local mode="$1"
  printf "%s\n" "${mode}" > "${INSTALL_MODE_FILE}"
}

current_install_mode() {
  if [[ -f "${INSTALL_MODE_FILE}" ]]; then
    cat "${INSTALL_MODE_FILE}"
    return
  fi

  if brew list --versions prometheus >/dev/null 2>&1 ||
     brew list --versions alertmanager >/dev/null 2>&1 ||
     brew list --versions grafana >/dev/null 2>&1; then
    printf "native"
    return
  fi

  if docker_available; then
    printf "docker"
    return
  fi

  printf "native"
}

ensure_render_dir() {
  mkdir -p "${RENDER_DIR}/docker"
  mkdir -p "${RENDER_DIR}/native"
}

ensure_data_dirs() {
  mkdir -p "${DATA_DIR}/prometheus"
  mkdir -p "${DATA_DIR}/alertmanager"
  mkdir -p "${DATA_DIR}/grafana"
  mkdir -p "${TEXTFILE_COLLECTOR_DIR}"
}

ensure_native_dirs() {
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

render_mode_configs() {
  local mode="$1"
  local mode_dir="${RENDER_DIR}/${mode}"

  ensure_render_dir
  ensure_data_dirs
  mkdir -p "${mode_dir}/grafana-provisioning/datasources"
  mkdir -p "${mode_dir}/grafana-provisioning/dashboards"

  case "${mode}" in
    docker)
      export LOCAL_NODE_EXPORTER_TARGET="host.docker.internal:${NODE_EXPORTER_PORT}"
      export PROMETHEUS_SELF_TARGET="prometheus:9090"
      export ALERTMANAGER_TARGET="alertmanager:9093"
      export PROMETHEUS_RULES_PATH="/etc/prometheus/alert.rules.yml"
      export NODE_EXPORTERS_FILE_PATH="/etc/prometheus/file_sd/node_exporters.yml"
      export PROMETHEUS_CONFIG_FILE_PATH="/etc/prometheus/prometheus.yml"
      export ALERTMANAGER_CONFIG_FILE_PATH="/etc/alertmanager/alertmanager.yml"
      export PROMETHEUS_DATASOURCE_URL="http://prometheus:9090"
      export GRAFANA_DASHBOARDS_PATH="/var/lib/grafana/dashboards"
      export BARK_WEBHOOK_URL_EFFECTIVE="http://bark-bridge:${BARK_BRIDGE_PORT}/alertmanager"
      ;;
    native)
      export LOCAL_NODE_EXPORTER_TARGET="${LOCAL_STATUS_HOST}:${NODE_EXPORTER_PORT}"
      export PROMETHEUS_SELF_TARGET="${LOCAL_STATUS_HOST}:${PROMETHEUS_PORT}"
      export ALERTMANAGER_TARGET="${LOCAL_STATUS_HOST}:${ALERTMANAGER_PORT}"
      export PROMETHEUS_RULES_PATH="${PROMETHEUS_RULES_DEST}"
      export NODE_EXPORTERS_FILE_PATH="${mode_dir}/node_exporters.yml"
      export PROMETHEUS_CONFIG_FILE_PATH="${PROMETHEUS_CONFIG_DEST}"
      export ALERTMANAGER_CONFIG_FILE_PATH="${ALERTMANAGER_CONFIG_DEST}"
      export PROMETHEUS_DATASOURCE_URL="http://${LOCAL_STATUS_HOST}:${PROMETHEUS_PORT}"
      export GRAFANA_DASHBOARDS_PATH="${GRAFANA_DASHBOARDS_DEST}"
      export BARK_WEBHOOK_URL_EFFECTIVE="http://${BARK_BRIDGE_BIND_ADDRESS}:${BARK_BRIDGE_PORT}/alertmanager"
      ;;
    *)
      die "不支持的 render 模式: ${mode}"
      ;;
  esac

  render_template "${SCRIPT_DIR}/prometheus.yml" "${mode_dir}/prometheus.yml"
  render_template "${SCRIPT_DIR}/alert.rules.yml" "${mode_dir}/alert.rules.yml"
  render_template "${SCRIPT_DIR}/targets/node_exporters.yml" "${mode_dir}/node_exporters.yml"
  render_template "${SCRIPT_DIR}/templates/node_exporter.args" "${mode_dir}/node_exporter.args"
  render_template "${SCRIPT_DIR}/templates/prometheus.args" "${mode_dir}/prometheus.args"
  render_template "${SCRIPT_DIR}/templates/alertmanager.args" "${mode_dir}/alertmanager.args"
  render_template "${SCRIPT_DIR}/templates/grafana.ini" "${mode_dir}/grafana.ini"
  render_template "${SCRIPT_DIR}/grafana-provisioning/datasources/prometheus.yml" "${mode_dir}/grafana-provisioning/datasources/prometheus.yml"
  render_template "${SCRIPT_DIR}/grafana-provisioning/dashboards/dashboards.yml" "${mode_dir}/grafana-provisioning/dashboards/dashboards.yml"

  local bark_enabled="false"
  local telegram_enabled="false"

  if [[ -n "${BARK_DEVICE_KEY}" ]]; then
    bark_enabled="true"
  fi

  if [[ -n "${TELEGRAM_BOT_TOKEN}" && -n "${TELEGRAM_CHAT_ID}" ]]; then
    telegram_enabled="true"
  fi

  if [[ "${bark_enabled}" == "true" || "${telegram_enabled}" == "true" ]]; then
    export ALERTMANAGER_DEFAULT_RECEIVER="ops-default"
  else
    export ALERTMANAGER_DEFAULT_RECEIVER="default-null"
  fi

  local alertmanager_rendered="${mode_dir}/alertmanager.yml"
  cat > "${alertmanager_rendered}" <<EOF
global:
  resolve_timeout: 5m

route:
  receiver: ${ALERTMANAGER_DEFAULT_RECEIVER}
  group_by: ["alertname", "instance", "severity"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: default-null
EOF

  if [[ "${bark_enabled}" == "true" || "${telegram_enabled}" == "true" ]]; then
    cat >> "${alertmanager_rendered}" <<EOF
  - name: ops-default
EOF
  fi

  if [[ "${bark_enabled}" == "true" ]]; then
    cat >> "${alertmanager_rendered}" <<EOF
    webhook_configs:
      - url: "${BARK_WEBHOOK_URL_EFFECTIVE}"
        send_resolved: true
EOF
  fi

  if [[ "${telegram_enabled}" == "true" ]]; then
    cat >> "${alertmanager_rendered}" <<EOF
    telegram_configs:
      - bot_token: "${TELEGRAM_BOT_TOKEN}"
        chat_id: ${TELEGRAM_CHAT_ID}
        send_resolved: true
        message: |
          [${MONITORED_HOSTNAME}] {{ .Status | toUpper }} - {{ .CommonLabels.alertname }}
          {{ range .Alerts -}}
          summary={{ .Annotations.summary }}
          description={{ .Annotations.description }}
          severity={{ .Labels.severity }}
          {{ end }}
EOF
  fi
}

bark_bridge_enabled() {
  [[ -n "${BARK_DEVICE_KEY}" ]]
}

start_native_bark_bridge() {
  if ! bark_bridge_enabled; then
    return
  fi

  require_command python3
  mkdir -p "${DATA_DIR}"

  stop_native_bark_bridge

  (
    cd "${SCRIPT_DIR}"
    nohup python3 "${SCRIPT_DIR}/bridges/bark_webhook_bridge.py" \
      >> "${BARK_BRIDGE_LOG_FILE}" 2>&1 &
    echo $! > "${BARK_BRIDGE_PID_FILE}"
  )

  for _ in 1 2 3 4 5; do
    if curl -fsS "http://${BARK_BRIDGE_BIND_ADDRESS}:${BARK_BRIDGE_PORT}/healthz" >/dev/null 2>&1; then
      log_success "Bark bridge 已启动"
      return
    fi
    sleep 1
  done

  log_warn "Bark bridge 健康检查未通过，请检查 ${BARK_BRIDGE_LOG_FILE}"
}

stop_native_bark_bridge() {
  if [[ -f "${BARK_BRIDGE_PID_FILE}" ]]; then
    local bark_pid
    bark_pid="$(cat "${BARK_BRIDGE_PID_FILE}")"
    if [[ -n "${bark_pid}" ]] && kill -0 "${bark_pid}" >/dev/null 2>&1; then
      kill "${bark_pid}" >/dev/null 2>&1 || true
    fi
    rm -f "${BARK_BRIDGE_PID_FILE}"
  fi
}

ensure_rendered_configs() {
  render_mode_configs docker
  render_mode_configs native
}

sync_node_exporter_config() {
  ensure_rendered_configs
  ensure_data_dirs
  sync_with_backup "${RENDER_DIR}/native/node_exporter.args" "${NODE_EXPORTER_ARGS_DEST}"
}

sync_native_configs() {
  ensure_rendered_configs
  ensure_native_dirs

  sync_with_backup "${RENDER_DIR}/native/prometheus.yml" "${PROMETHEUS_CONFIG_DEST}"
  sync_with_backup "${RENDER_DIR}/native/alert.rules.yml" "${PROMETHEUS_RULES_DEST}"
  sync_with_backup "${RENDER_DIR}/native/prometheus.args" "${PROMETHEUS_ARGS_DEST}"
  sync_with_backup "${RENDER_DIR}/native/alertmanager.yml" "${ALERTMANAGER_CONFIG_DEST}"
  sync_with_backup "${RENDER_DIR}/native/alertmanager.args" "${ALERTMANAGER_ARGS_DEST}"
  sync_with_backup "${RENDER_DIR}/native/grafana.ini" "${GRAFANA_CONFIG_DEST}"
  sync_with_backup "${RENDER_DIR}/native/grafana-provisioning/datasources/prometheus.yml" "${GRAFANA_DATASOURCE_DEST}"
  sync_with_backup "${RENDER_DIR}/native/grafana-provisioning/dashboards/dashboards.yml" "${GRAFANA_DASHBOARD_PROVIDER_DEST}"
  sync_with_backup "${SCRIPT_DIR}/dashboards/macos-self-monitoring.json" "${GRAFANA_DASHBOARDS_DEST}/macos-self-monitoring.json"
}

sync_docker_configs() {
  ensure_rendered_configs
  ensure_data_dirs
}

docker_compose() {
  (
    cd "${SCRIPT_DIR}"
    docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${COMPOSE_ENV_FILE}" "$@"
  )
}

install_native_alertmanager() {
  set +e
  brew install alertmanager
  local alertmanager_install_rc=$?
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
}

install_native_stack() {
  require_command brew

  log_info "安装宿主机原生监控栈"
  brew install prometheus
  brew install node_exporter
  brew install grafana
  install_native_alertmanager

  sync_node_exporter_config
  sync_native_configs
  persist_install_mode native

  log_success "原生安装模式准备完成"
}

install_docker_stack() {
  require_command brew
  require_command docker

  log_info "安装宿主机 node_exporter，并准备 Docker 监控栈"
  brew install node_exporter

  sync_node_exporter_config
  sync_docker_configs
  docker_compose pull
  persist_install_mode docker

  log_success "Docker 安装模式准备完成"
}

start_native_stack() {
  require_command brew
  require_command curl

  sync_node_exporter_config
  sync_native_configs

  start_native_bark_bridge
  brew services restart prometheus
  brew services restart node_exporter
  brew services restart alertmanager
  brew services restart grafana

  persist_install_mode native
}

start_docker_stack() {
  require_command brew
  require_command docker
  require_command curl

  sync_node_exporter_config
  sync_docker_configs

  stop_native_bark_bridge
  brew services restart node_exporter
  docker_compose up -d

  persist_install_mode docker
}

stop_native_stack() {
  require_command brew
  stop_native_bark_bridge
  brew services stop grafana || true
  brew services stop alertmanager || true
  brew services stop prometheus || true
  brew services stop node_exporter || true
}

stop_docker_stack() {
  require_command brew
  require_command docker
  docker_compose down || true
  stop_native_bark_bridge
  brew services stop node_exporter || true
}

remove_path_if_exists() {
  local target="$1"
  if [[ -e "${target}" ]]; then
    rm -rf "${target}"
    log_warn "已删除旧文件/目录: ${target}"
  fi
}

remove_native_stack() {
  stop_native_stack

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

  remove_path_if_exists "${PROMETHEUS_CONFIG_DEST}"
  remove_path_if_exists "${PROMETHEUS_RULES_DEST}"
  remove_path_if_exists "${PROMETHEUS_ARGS_DEST}"
  remove_path_if_exists "${ALERTMANAGER_CONFIG_DEST}"
  remove_path_if_exists "${ALERTMANAGER_ARGS_DEST}"
  remove_path_if_exists "${GRAFANA_CONFIG_DEST}"
  remove_path_if_exists "${GRAFANA_DATASOURCE_DEST}"
  remove_path_if_exists "${GRAFANA_DASHBOARD_PROVIDER_DEST}"
  remove_path_if_exists "${PROMETHEUS_STORAGE_PATH}"
  remove_path_if_exists "${ALERTMANAGER_STORAGE_PATH}"
  remove_path_if_exists "${GRAFANA_DATA_PATH}"
  remove_path_if_exists "${GRAFANA_LOG_PATH}"
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
