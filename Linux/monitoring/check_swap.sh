#!/bin/bash
# /opt/monitoring/check_swap.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "free"

HOST=$(hostname)

read -r TOTAL_SWAP USED_SWAP <<< $(free -m | awk '/^Swap:/ {print $2, $3}')

# Если свопа нет
if (( TOTAL_SWAP == 0 )); then
    exit 0
fi

PERCENT_USED=$(( 100 * USED_SWAP / TOTAL_SWAP ))

if (( PERCENT_USED > SWAP_THRESHOLD )); then
    MSG=$(cat <<EOF
🔂 *High SWAP Usage: ${HOST}*

📈 Used: ${PERCENT_USED}% (${USED_SWAP}MB)
💾 Total: ${TOTAL_SWAP}MB
⛔ Threshold: > ${SWAP_THRESHOLD}%
EOF
)
    send_telegram "$MSG"
    log_msg "ALERT: High SWAP usage (${PERCENT_USED}%)"
fi

exit 0