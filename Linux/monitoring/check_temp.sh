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

# Парсинг вывода sensors (Имя: Температура)
SENSORS_DATA=$(sensors | sed -n -E 's/^(.*[^[:space:]]):\s+\+([0-9.]+).*/\1:\2/p')

while IFS=':' read -r NAME TEMP; do
    TEMP_INT=${TEMP%.*} # Отбрасываем дробную часть

    if (( TEMP_INT >= TEMP_CRITICAL )); then
        ALERTS+="🔥 *${NAME}:* \`${TEMP}°C\` (Crit: ${TEMP_CRITICAL})\n"
    elif (( TEMP_INT >= TEMP_WARNING )); then
        ALERTS+="⚠️ *${NAME}:* \`${TEMP}°C\` (Warn: ${TEMP_WARNING})\n"
    fi
done <<< "$SENSORS_DATA"

if [[ -n "$ALERTS" ]]; then
    MSG=$(cat <<EOF
🌡️ *Temperature Alert: ${HOST}*

${ALERTS}
EOF
)
    send_telegram "$MSG"
    log_msg "ALERT: High temperature detected."
fi

exit 0