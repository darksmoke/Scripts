#!/bin/bash
# /opt/monitoring/check_iowait.sh
# v.1.3 - Added Maintenance Window support
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "iostat"
check_dependency "bc"

# === БЛОК ПРОВЕРКИ MAINTENANCE ===
# Если переменные заданы
if [[ -n "${IOWAIT_MNT_START:-}" && -n "${IOWAIT_MNT_END:-}" ]]; then
    # Получаем текущий час (10# принуждает использовать десятичную систему, чтобы 08 не считалось восьмеричным)
    CURRENT_HOUR=$((10#$(date +%H)))
    MNT_START=$((10#$IOWAIT_MNT_START))
    MNT_END=$((10#$IOWAIT_MNT_END))

    IS_MAINTENANCE=0

    if (( MNT_START < MNT_END )); then
        if (( CURRENT_HOUR >= MNT_START && CURRENT_HOUR < MNT_END )); then
            IS_MAINTENANCE=1
        fi
    else
        if (( CURRENT_HOUR >= MNT_START || CURRENT_HOUR < MNT_END )); then
            IS_MAINTENANCE=1
        fi
    fi

    if [[ "$IS_MAINTENANCE" -eq 1 ]]; then

        exit 0
    fi
fi
# =================================

HOST=$(hostname)

CURRENT_IOWAIT=$(LC_ALL=C iostat -c 2 2 | awk 'NF > 0 {last=$4} END {print last}')

if [[ -z "$CURRENT_IOWAIT" ]]; then
    log_msg "ERROR: Failed to parse iostat output."
    exit 1
fi

IS_OVERLOADED=$(echo "${CURRENT_IOWAIT} > ${IOWAIT_THRESHOLD}" | bc -l)
ALERT_ID="disk_high_iowait"

if [[ "$IS_OVERLOADED" -eq 1 ]]; then
    MSG=$(cat <<EOF
️   *Высокий IO Wait: ${HOST}*
   Текущий: \`${CURRENT_IOWAIT}%\`
   Порог: \`${IOWAIT_THRESHOLD}%\`
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0