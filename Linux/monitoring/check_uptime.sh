#!/bin/bash
# /opt/monitoring/check_uptime.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

HOST=$(hostname)

# Получаем uptime в минутах
UPTIME_MIN=$(awk '{print int($1/60)}' /proc/uptime)

# Если uptime меньше порога (например, 60 минут)
if (( UPTIME_MIN < UPTIME_MIN_MINUTES )); then
    MSG=$(cat <<EOF
🔄 *System Reboot Detected: ${HOST}*

⏱️ Uptime: ${UPTIME_MIN} min
⛔ Threshold: < ${UPTIME_MIN_MINUTES} min

Server was rebooted recently.
EOF
)
    # Доп. проверка: отправлять, только если не отправляли недавно (через lock файл),
    # но для простоты оставим прямую отправку (скрипт должен запускаться реже или нужна защита от спама).
    send_telegram "$MSG"
    log_msg "ALERT: System Reboot detected (Uptime: ${UPTIME_MIN}m)"
fi

exit 0