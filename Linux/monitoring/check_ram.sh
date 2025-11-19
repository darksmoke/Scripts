#!/bin/bash
# /opt/monitoring/check_ram.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "free"
check_dependency "awk"

HOST=$(hostname)

# Получаем Total и Available
read -r TOTAL_MB AVAILABLE_MB <<< $(free -m | awk '/^Mem:/ {print $2, $7}')

if [[ "$TOTAL_MB" -eq 0 ]]; then
    log_msg "ERROR: RAM detection failed (Total is 0)"
    exit 1
fi

# Расчет процента доступной памяти
PERCENT_AVAILABLE=$(( 100 * AVAILABLE_MB / TOTAL_MB ))

if (( PERCENT_AVAILABLE < RAM_THRESHOLD )); then
    MSG=$(cat <<EOF
🧠 *Low Memory Alert: ${HOST}*

📉 Free RAM: ${PERCENT_AVAILABLE}% (${AVAILABLE_MB}MB)
💾 Total RAM: ${TOTAL_MB}MB
⛔ Threshold: < ${RAM_THRESHOLD}%
EOF
)
    send_telegram "$MSG"
    log_msg "ALERT: Low RAM (${PERCENT_AVAILABLE}% free)"
fi

exit 0