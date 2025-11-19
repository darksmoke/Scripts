#!/bin/bash
# /opt/monitoring/check_iowait.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "iostat"
check_dependency "bc"

HOST=$(hostname)

# Берем второй отчет iostat (первый - это среднее с момента загрузки)
# awk '{print $4}' обычно соответствует %iowait в стандартном выводе, но лучше проверять заголовки.
# Для простоты оставляем $4, так как это стандарт для iostat -c.
CURRENT_IOWAIT=$(LC_ALL=C iostat -c 2 2 | tail -n 1 | awk '{print $4}')

# Сравнение Float через bc
IS_OVERLOADED=$(echo "${CURRENT_IOWAIT} > ${IOWAIT_THRESHOLD}" | bc -l)

if [[ "$IS_OVERLOADED" -eq 1 ]]; then
    MSG=$(cat <<EOF
⚡️ *High IO Wait: ${HOST}*

📈 Current Wait: \`${CURRENT_IOWAIT}%\`
⛔ Threshold: \`${IOWAIT_THRESHOLD}%\`

Possible disk bottleneck.
EOF
)
    send_telegram "$MSG"
    log_msg "ALERT: High IO Wait (${CURRENT_IOWAIT}%)"
fi

exit 0