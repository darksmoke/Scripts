#!/bin/bash
# /opt/monitoring/check_cpu.sh

# Установка путей
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

# Проверка зависимости
check_dependency "bc"

# Логика
CORES=$(nproc)
LOAD_AVG=$(awk '{print $1}' /proc/loadavg)
# Расчет порога: (Ядра * Порог%) / 100
THRESHOLD_VAL=$(echo "scale=2; ${CORES} * ${CPU_THRESHOLD} / 100" | bc)

# Сравнение
IS_OVERLOADED=$(echo "${LOAD_AVG} > ${THRESHOLD_VAL}" | bc)

if [[ "$IS_OVERLOADED" -eq 1 ]]; then
    HOST=$(hostname)
    MSG=$(cat <<EOF
🔥 *High CPU Load: ${HOST}*

⚙️ Cores: ${CORES}
📈 Load Avg (1m): \`${LOAD_AVG}\`
⛔ Threshold: \`${THRESHOLD_VAL}\` (> ${CPU_THRESHOLD}%)
EOF
)
    send_telegram "$MSG"
    log_msg "ALERT: CPU Load High ($LOAD_AVG)"
fi

exit 0