#!/bin/bash
# /opt/monitoring/check_disk.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "df"

HOST=$(hostname)

# Получаем список дисков
df -h --output=source,pcent,avail,size,target,fstype | tail -n +2 | \
grep -vE "${DISK_EXCLUDE_TYPE}" | grep -vE "${DISK_EXCLUDE_PATH}" | while read -r line; do

    PERCENT_USED_STR=$(echo "$line" | awk '{print $2}')
    AVAIL=$(echo "$line" | awk '{print $3}')
    MOUNT=$(echo "$line" | awk '{print $5}')
    
    # Создаем ID для алерта (заменяем слеши на подчеркивания)
    # Пример: disk_boot_efi
    ALERT_ID="disk_$(echo "$MOUNT" | tr '/' '_')"
    
    PERCENT_USED=${PERCENT_USED_STR%\%}
    PERCENT_FREE=$((100 - PERCENT_USED))

    if (( PERCENT_FREE < DISK_THRESHOLD )); then
        # Формируем текст
        MSG=$(cat <<EOF
💽 *Мало места: ${HOST}*
Раздел: \`${MOUNT}\`
Свободно: ${PERCENT_FREE}% (${AVAIL})
Порог: < ${DISK_THRESHOLD}%
EOF
)
        # Вызываем менеджер алертов с флагом ERROR
        manage_alert "$ALERT_ID" "ERROR" "$MSG"
    else
        # Вызываем менеджер с флагом OK (чтобы сбросить алерт, если он был)
        manage_alert "$ALERT_ID" "OK" ""
    fi
done

exit 0
