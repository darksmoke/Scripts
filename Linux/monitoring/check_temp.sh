#!/bin/bash
# /opt/monitoring/check_temp.sh
# v.1.1 - только температурные строки, TEMP_CRITICAL, лог при пустом sensors
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

# Берём только строки с температурой: "+35.0°C" (UTF-8) или "+35.0 C" (C-локаль).
# Раньше под регулярку попадали и напряжения ("in0: +1.20 V").
SENSORS_DATA=$(sensors 2>/dev/null | sed -n -E 's/^(.*[^[:space:]]):[[:space:]]+\+([0-9.]+)[^0-9A-Za-z ]*[ ]?C([[:space:]]|$).*/\1:\2/p')

if [[ -z "$SENSORS_DATA" ]]; then
    # Не алерт: на ВМ датчиков нет штатно. Но в логе видно, что проверка
    # ничего не проверяет (на железе — запустить sensors-detect).
    # Пишем один раз, а не каждые 5 минут.
    if [[ ! -f "${STATE_DIR}/sensors_empty.flag" ]]; then
        log_msg "WARN: sensors returned no temperature readings"
        touch "${STATE_DIR}/sensors_empty.flag"
    fi
    exit 0
fi
rm -f "${STATE_DIR}/sensors_empty.flag"

while IFS=':' read -r NAME TEMP; do
    TEMP_INT=${TEMP%.*}
    if (( TEMP_INT >= TEMP_CRITICAL )); then
        ALERTS+="🆘 *${NAME}:* \`${TEMP}°C\` (Crit: ${TEMP_CRITICAL})\n"
        HAS_ERROR=1
    elif (( TEMP_INT >= TEMP_WARNING )); then
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
