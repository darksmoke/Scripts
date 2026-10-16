#!/bin/bash
# /opt/monitoring/check_ram.sh
# v.1.1 - Реальная проверка RAM (раньше файл был копией check_iowait.sh)
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

HOST=$(hostname)

# MemAvailable — оценка ядра, сколько памяти можно отдать приложениям без
# свопа (свободная + освобождаемый кэш). "free" из MemFree тут не годится:
# на любом долго работающем сервере кэш съедает почти всю MemFree.
TOTAL_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
AVAIL_KB=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

if [[ -z "$TOTAL_KB" || -z "$AVAIL_KB" ]] || (( TOTAL_KB == 0 )); then
    log_msg "ERROR: Failed to parse /proc/meminfo"
    exit 1
fi

PERCENT_FREE=$(( 100 * AVAIL_KB / TOTAL_KB ))
ALERT_ID="ram_low"

if (( PERCENT_FREE < RAM_THRESHOLD )); then
    MSG=$(cat <<EOM
🧠 *Мало RAM: ${HOST}*
Доступно: ${PERCENT_FREE}% ($(( AVAIL_KB / 1024 ))MB из $(( TOTAL_KB / 1024 ))MB)
Порог: < ${RAM_THRESHOLD}%
EOM
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
