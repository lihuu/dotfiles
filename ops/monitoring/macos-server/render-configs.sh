#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults
ensure_render_dir

if [[ -n "${ALERT_WEBHOOK_URL}" ]]; then
  export ALERTMANAGER_DEFAULT_RECEIVER="telegram-webhook"
elif [[ -n "${TELEGRAM_BOT_TOKEN}" && -n "${TELEGRAM_CHAT_ID}" ]]; then
  export ALERTMANAGER_DEFAULT_RECEIVER="telegram-direct"
else
  export ALERTMANAGER_DEFAULT_RECEIVER="default-null"
fi

export ALERT_WEBHOOK_URL_EFFECTIVE="${ALERT_WEBHOOK_URL:-http://127.0.0.1:65535/disabled}"

render_template "${SCRIPT_DIR}/prometheus.yml" "${RENDER_DIR}/prometheus.yml"
render_template "${SCRIPT_DIR}/alert.rules.yml" "${RENDER_DIR}/alert.rules.yml"
render_template "${SCRIPT_DIR}/templates/prometheus.args" "${RENDER_DIR}/prometheus.args"
render_template "${SCRIPT_DIR}/templates/node_exporter.args" "${RENDER_DIR}/node_exporter.args"
render_template "${SCRIPT_DIR}/templates/alertmanager.args" "${RENDER_DIR}/alertmanager.args"
render_template "${SCRIPT_DIR}/templates/grafana.ini" "${RENDER_DIR}/grafana.ini"
render_template "${SCRIPT_DIR}/grafana-provisioning/datasources/prometheus.yml" "${RENDER_DIR}/grafana-provisioning/datasources/prometheus.yml"
render_template "${SCRIPT_DIR}/grafana-provisioning/dashboards/dashboards.yml" "${RENDER_DIR}/grafana-provisioning/dashboards/dashboards.yml"

ALERTMANAGER_RENDERED="${RENDER_DIR}/alertmanager.yml"
cat > "${ALERTMANAGER_RENDERED}" <<EOF
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

if [[ -n "${ALERT_WEBHOOK_URL}" ]]; then
  cat >> "${ALERTMANAGER_RENDERED}" <<EOF
  - name: telegram-webhook
    webhook_configs:
      - url: "${ALERT_WEBHOOK_URL}"
        send_resolved: true
EOF
fi

if [[ -n "${TELEGRAM_BOT_TOKEN}" && -n "${TELEGRAM_CHAT_ID}" ]]; then
  cat >> "${ALERTMANAGER_RENDERED}" <<EOF
  - name: telegram-direct
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

log_success "已渲染配置到 ${RENDER_DIR}"
