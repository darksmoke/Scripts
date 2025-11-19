#!/bin/bash
# /opt/monitoring/check_swap.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "free"

HOST=$(hostname)

read -r TOTAL_SWAP USED_SWAP <<< $(free -m | awk '/^Swap:/ {print $2, $3}')

if (( TOTAL_SWAP == 0 )); then
    exit 0
fi

PERCENT_USED=$(( 100 * USED_SWAP / TOTAL_SWAP ))
ALERT_ID="swap_high_usage"

if (( PERCENT_USED > SWAP_THRESHOLD )); then
    MSG=$(cat <<EOF
🔂 *Заполнен SWAP: ${HOST}*
📈 Занято: ${PERCENT_USED}% (${USED_SWAP}MB)
💾 Всего: ${TOTAL_SWAP}MB
⛔ Порог: > ${SWAP_THRESHOLD}%
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
