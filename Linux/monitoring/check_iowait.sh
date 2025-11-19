#!/bin/bash
# /opt/monitoring/check_iowait.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "iostat"
check_dependency "bc"

HOST=$(hostname)

# 1. Получаем значение
# NF > 0 : обрабатываем только строки, где есть данные (исключаем пустые)
# {last=$4} : запоминаем 4-ю колонку (обычно %iowait)
# END {print last} : выводим последнее запомненное значение (из второго отчета iostat)
CURRENT_IOWAIT=$(LC_ALL=C iostat -c 2 2 | awk 'NF > 0 {last=$4} END {print last}')

# 2. ВАЖНО: Проверка на сбой получения данных
if [[ -z "$CURRENT_IOWAIT" ]]; then
    # Пишем в лог, что мониторинг сломался
    log_msg "ERROR: Failed to parse iostat output. Variable is empty."
    # Завершаем работу с кодом ошибки, не пытаясь считать математику
    exit 1
fi

# 3. Математика (выполняется только если данные получены)
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
