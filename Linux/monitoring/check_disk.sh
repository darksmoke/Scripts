#!/bin/bash
# /opt/monitoring/check_disk.sh
# v.1.1 - df timeout, inode check, exact exclusions, safe parsing
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "df"

HOST=$(hostname)

# df на зависшем сетевом монтировании (NFS/CIFS) висит бесконечно — без
# таймаута проверка молча не работала бы вообще.
DF_OUT=$(timeout 60 df -h --output=source,pcent,ipcent,avail,fstype,target 2>/dev/null)
DF_RC=$?
if (( DF_RC == 124 )); then
    MSG=$(cat <<EOF
*df не ответил за 60 с: ${HOST}*
Вероятно, зависло сетевое монтирование (NFS/CIFS). Место на дисках не проверено.
EOF
)
    manage_alert "disk_df_timeout" "ERROR" "$MSG"
    exit 0
fi
manage_alert "disk_df_timeout" "OK" ""

# Исключения сравниваем с конкретными полями, а не со всей строкой:
# раньше "/snap" выкидывал и /tank/snapshots, а тип "overlay" — любую
# строку, где это слово встречалось.
echo "$DF_OUT" | tail -n +2 | while read -r SRC PCENT IPCENT AVAIL FSTYPE MOUNT; do

    [[ -z "${MOUNT:-}" ]] && continue
    # Тип — по началу имени ("fuse" исключает и fuse.sshfs), путь — по
    # началу пути ("/run" исключает /run/user/..., но не /tank/run).
    [[ "$FSTYPE" =~ ^(${DISK_EXCLUDE_TYPE}) ]] && continue
    [[ "$MOUNT" =~ ^(${DISK_EXCLUDE_PATH})(/|$) ]] && continue

    # Создаем ID для алерта (заменяем слеши на подчеркивания)
    # Пример: disk_boot_efi. Схема как раньше — чтобы активные алерты
    # после обновления корректно закрылись, а не зависли под старым ID.
    MOUNT_ID=$(echo "$MOUNT" | tr '/' '_')
    ALERT_ID="disk_${MOUNT_ID}"

    # У части ФС df выдаёт "-" вместо процента — такие пропускаем, а не
    # роняем цикл арифметической ошибкой.
    PERCENT_USED=${PCENT%\%}
    if [[ "$PERCENT_USED" =~ ^[0-9]+$ ]]; then
        PERCENT_FREE=$((100 - PERCENT_USED))

        if (( PERCENT_FREE < DISK_THRESHOLD )); then
            MSG=$(cat <<EOF
*Мало места: ${HOST}*
Раздел: \`${MOUNT}\`
Свободно: ${PERCENT_FREE}% (${AVAIL})
Порог: < ${DISK_THRESHOLD}%
EOF
)
            manage_alert "$ALERT_ID" "ERROR" "$MSG"
        else
            manage_alert "$ALERT_ID" "OK" ""
        fi
    fi

    # Закончившиеся inode: место есть, а файлы создать нельзя.
    # Порог тот же, что и для места. У ФС без фиксированных inode
    # (btrfs, vfat, zfs) df выдаёт "-" — пропускаем.
    INODE_USED=${IPCENT%\%}
    if [[ "$INODE_USED" =~ ^[0-9]+$ ]]; then
        INODE_FREE=$((100 - INODE_USED))

        if (( INODE_FREE < DISK_THRESHOLD )); then
            MSG=$(cat <<EOF
*Заканчиваются inode: ${HOST}*
Раздел: \`${MOUNT}\`
Свободно inode: ${INODE_FREE}%
Порог: < ${DISK_THRESHOLD}%
EOF
)
            manage_alert "inode_${MOUNT_ID}" "ERROR" "$MSG"
        else
            manage_alert "inode_${MOUNT_ID}" "OK" ""
        fi
    fi
done

exit 0
