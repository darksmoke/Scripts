#!/bin/bash
# /opt/monitoring/check_cpu.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "bc"

HOST=$(hostname)
CORES=$(nproc)
LOAD_AVG=$(awk '{print $1}' /proc/loadavg)
# Расчет порога
THRESHOLD_VAL=$(echo "scale=2; ${CORES} * ${CPU_THRESHOLD} / 100" | bc)

# Сравнение
IS_OVERLOADED=$(echo "${LOAD_AVG} > ${THRESHOLD_VAL}" | bc)

ALERT_ID="cpu_high_load"

if [[ "$IS_OVERLOADED" -eq 1 ]]; then
    MSG=$(cat <<EOF
🔥 *Высокая нагрузка CPU: ${HOST}*
Ядер: ${CORES}
Load Avg (1m): \`${LOAD_AVG}\`
Порог: \`${THRESHOLD_VAL}\` (> ${CPU_THRESHOLD}%)
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
