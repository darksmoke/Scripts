#!/bin/bash
# /opt/monitoring/check_uptime.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

HOST=$(hostname)
UPTIME_MIN=$(awk '{print int($1/60)}' /proc/uptime)
ALERT_ID="system_reboot"

if (( UPTIME_MIN < UPTIME_MIN_MINUTES )); then
    MSG=$(cat <<EOF
🔄 *Обнаружена перезагрузка: ${HOST}*
Uptime: ${UPTIME_MIN} мин
Порог: < ${UPTIME_MIN_MINUTES} мин
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    # Если аптайм стал больше порога, сообщаем о стабилизации (один раз, и удаляем лок)
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
