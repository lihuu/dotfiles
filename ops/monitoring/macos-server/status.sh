#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew
require_command curl
require_command lsof

printf "\n%s== brew services ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
brew services list | awk 'NR == 1 || $1 ~ /^(prometheus|node_exporter|alertmanager|grafana)$/'

printf "\n%s== Port Status ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
show_port_status "${PROMETHEUS_PORT}"
show_port_status "${NODE_EXPORTER_PORT}"
show_port_status "${ALERTMANAGER_PORT}"
show_port_status "${GRAFANA_PORT}"

printf "\n%s== Health Checks ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
for url in \
  "http://${PROMETHEUS_LISTEN_ADDRESS}:${PROMETHEUS_PORT}/-/healthy" \
  "http://${PROMETHEUS_LISTEN_ADDRESS}:${PROMETHEUS_PORT}/api/v1/targets" \
  "http://${NODE_EXPORTER_LISTEN_ADDRESS}:${NODE_EXPORTER_PORT}/metrics" \
  "http://${ALERTMANAGER_LISTEN_ADDRESS}:${ALERTMANAGER_PORT}/-/healthy" \
  "http://${ALERTMANAGER_LISTEN_ADDRESS}:${ALERTMANAGER_PORT}/api/v2/status" \
  "http://${GRAFANA_LISTEN_ADDRESS}:${GRAFANA_PORT}/api/health"; do
  http_code="$(curl -sS -o /dev/null -w "%{http_code}" "${url}" || true)"
  printf "%-70s %s\n" "${url}" "${http_code}"
done

printf "\n%s== Quick URLs ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
print_healthcheck_urls
