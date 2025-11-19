#!/bin/bash
# /opt/monitoring/check_ram.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "free"

HOST=$(hostname)

read -r TOTAL_MB AVAILABLE_MB <<< $(free -m | awk '/^Mem:/ {print $2, $7}')

if [[ "$TOTAL_MB" -eq 0 ]]; then
    log_msg "ERROR: RAM detection failed"
    exit 1
fi

PERCENT_AVAILABLE=$(( 100 * AVAILABLE_MB / TOTAL_MB ))
ALERT_ID="ram_low_memory"

if (( PERCENT_AVAILABLE < RAM_THRESHOLD )); then
    MSG=$(cat <<EOF
🧠 *Мало памяти (RAM): ${HOST}*
📉 Свободно: ${PERCENT_AVAILABLE}% (${AVAILABLE_MB}MB)
💾 Всего: ${TOTAL_MB}MB
⛔ Порог: < ${RAM_THRESHOLD}%
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
