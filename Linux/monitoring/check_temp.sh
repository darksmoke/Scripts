#!/bin/bash
# /opt/monitoring/check_temp.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

if ! command -v sensors &> /dev/null; then
    exit 0
fi

HOST=$(hostname)
ALERTS=""
HAS_ERROR=0

SENSORS_DATA=$(sensors | sed -n -E 's/^(.*[^[:space:]]):\s+\+([0-9.]+).*/\1:\2/p')

while IFS=':' read -r NAME TEMP; do
    TEMP_INT=${TEMP%.*} 
    if (( TEMP_INT >= TEMP_WARNING )); then
        ALERTS+="🔥 *${NAME}:* \`${TEMP}°C\` (Warn: ${TEMP_WARNING})\n"
        HAS_ERROR=1
    fi
done <<< "$SENSORS_DATA"

ALERT_ID="system_temperature"

if [[ "$HAS_ERROR" -eq 1 ]]; then
    MSG=$(cat <<EOF
🌡️ *Перегрев сервера: ${HOST}*
${ALERTS}
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
