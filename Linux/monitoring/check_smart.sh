#!/bin/bash
# /opt/monitoring/check_smart.sh
# v.1.4 - Ignore removable devices (USB)
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "smartctl"
check_dependency "lsblk"

HOST=$(hostname)
REPORT=""
HAS_ERROR=0

get_attr() {
    echo "$1" | awk -v id="$2" '$1 == id {print $10; exit}' | sed 's/^0*//' | awk '{if($1=="") print 0; else print $1}'
}

# ИЗМЕНЕНИЕ: Добавили колонку RM (Removable) в вывод lsblk.
# awk проверяет: если колонка 2 (RM) равна 0 И колонка 3 (TYPE) равна disk -> печатаем имя.
DISKS=$(lsblk -d -n -o NAME,RM,TYPE | awk '$2 == 0 && $3 == "disk" {print "/dev/"$1}')

for disk in $DISKS; do
    DISK_ISSUES=""
    
    # Пытаемся получить статус здоровья
    # Добавили тайм-аут, чтобы не висело на битых дисках
    HEALTH_OUTPUT=$(timeout 10 smartctl -H "$disk" 2>&1)
    EXIT_CODE=$?

    # Парсим результат
    HEALTH=$(echo "$HEALTH_OUTPUT" | grep -i "result" | awk -F: '{print $2}' | xargs) || HEALTH="UNKNOWN"
    
    # Если smartctl вернул ошибку выполнения (например, диск не поддерживает SMART),
    # но при этом не сказал явно FAILED, то помечаем как WARN, а не CRIT, или пропускаем.
    
    if [[ -z "$HEALTH" ]]; then
        # Если статус пустой, значит smartctl не смог прочитать данные
        # Это проблема, но возможно диск просто не поддерживает SMART (старые RAID контроллеры и т.д.)
        DISK_ISSUES+=" SMART Status not available (Check manually)\n"
    elif [[ "$HEALTH" != "PASSED" && "$HEALTH" != "OK" ]]; then
        DISK_ISSUES+="🔴 Health Check Failed: ${HEALTH}\n"
    else
        # Если здоровье OK, проверяем атрибуты
        ATTRS=$(smartctl -A "$disk" 2>/dev/null) || true
        
        RSC=$(get_attr "$ATTRS" 5)
        if (( RSC > SMART_REALLOCATED_LIMIT )); then
            DISK_ISSUES+=" Reallocated Sectors (ID 5): ${RSC}\n"
        fi
        
        PSC=$(get_attr "$ATTRS" 197)
        if (( PSC > SMART_PENDING_LIMIT )); then
            DISK_ISSUES+=" Pending Sectors (ID 197): ${PSC}\n"
        fi
    fi

    if [[ -n "$DISK_ISSUES" ]]; then
        REPORT+=" *Disk ${disk}*:\n${DISK_ISSUES}\n"
        HAS_ERROR=1
    fi
done

ALERT_ID="smart_health"

if [[ "$HAS_ERROR" -eq 1 ]]; then
    MSG=$(cat <<EOF
🔧 *SMART Ошибки: ${HOST}*
${REPORT}
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
