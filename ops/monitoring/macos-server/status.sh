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
require_command docker

printf "\n%s== brew services (host) ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
brew services list | awk 'NR == 1 || $1 ~ /^(node_exporter)$/'

printf "\n%s== docker compose ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
docker_compose ps

printf "\n%s== Port Status ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
show_port_status "${PROMETHEUS_PORT}"
show_port_status "${NODE_EXPORTER_PORT}"
show_port_status "${ALERTMANAGER_PORT}"
show_port_status "${GRAFANA_PORT}"

printf "\n%s== Health Checks ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
for url in \
  "http://${LOCAL_STATUS_HOST}:${PROMETHEUS_PORT}/-/healthy" \
  "http://${LOCAL_STATUS_HOST}:${PROMETHEUS_PORT}/api/v1/targets" \
  "http://${LOCAL_STATUS_HOST}:${NODE_EXPORTER_PORT}/metrics" \
  "http://${LOCAL_STATUS_HOST}:${ALERTMANAGER_PORT}/-/healthy" \
  "http://${LOCAL_STATUS_HOST}:${ALERTMANAGER_PORT}/api/v2/status" \
  "http://${LOCAL_STATUS_HOST}:${GRAFANA_PORT}/api/health"; do
  http_code="$(curl -sS -o /dev/null -w "%{http_code}" "${url}" || true)"
  printf "%-70s %s\n" "${url}" "${http_code}"
done

printf "\n%s== Quick URLs ==%s\n" "${COLOR_BLUE}" "${COLOR_RESET}"
print_healthcheck_urls
