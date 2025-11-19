#!/bin/bash
# /opt/monitoring/check_disk.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

# Проверяем наличие команды df
check_dependency "df"

HOST=$(hostname)

# Получаем список ФС. Исключаем заголовки (tail) и фильтруем по типам/путям из конфига
# Вывод df: Filesystem, Use%, Avail, Size, Mounted on, Type
df -h --output=source,pcent,avail,size,target,fstype | tail -n +2 | \
grep -vE "${DISK_EXCLUDE_TYPE}" | grep -vE "${DISK_EXCLUDE_PATH}" | while read -r line; do

    # Парсинг строки
    PERCENT_USED_STR=$(echo "$line" | awk '{print $2}')
    AVAIL=$(echo "$line" | awk '{print $3}')
    SIZE=$(echo "$line" | awk '{print $4}')
    MOUNT=$(echo "$line" | awk '{print $5}')
    
    # Удаляем %
    PERCENT_USED=${PERCENT_USED_STR%\%}
    PERCENT_FREE=$((100 - PERCENT_USED))

    # Проверка порога
    if (( PERCENT_FREE < DISK_THRESHOLD )); then
        MSG=$(cat <<EOF
💽 *Low Disk Space: ${HOST}*

💾 Path: \`${MOUNT}\`
📉 Free: ${PERCENT_FREE}% (${AVAIL})
💿 Total: ${SIZE}
⛔ Threshold: < ${DISK_THRESHOLD}%
EOF
)
        send_telegram "$MSG"
        log_msg "ALERT: Disk space low on $MOUNT (${PERCENT_FREE}% free)"
    fi
done

exit 0