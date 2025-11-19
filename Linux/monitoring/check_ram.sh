#!/bin/bash
# /opt/monitoring/check_iowait.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "iostat"
check_dependency "bc"

HOST=$(hostname)

# Безопасное получение значения
CURRENT_IOWAIT=$(LC_ALL=C iostat -c 2 2 | awk 'NF > 0 {last=$4} END {print last}')

if [[ -z "$CURRENT_IOWAIT" ]]; then
    log_msg "ERROR: Failed to parse iostat"
    exit 1
fi

IS_OVERLOADED=$(echo "${CURRENT_IOWAIT} > ${IOWAIT_THRESHOLD}" | bc -l)
ALERT_ID="disk_high_iowait"

if [[ "$IS_OVERLOADED" -eq 1 ]]; then
    MSG=$(cat <<EOF
⚡️ *Высокий IO Wait: ${HOST}*
📈 Текущий: \`${CURRENT_IOWAIT}%\`
⛔ Порог: \`${IOWAIT_THRESHOLD}%\`
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
