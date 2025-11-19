#!/bin/bash
# /opt/monitoring/check_smart.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "smartctl"
check_dependency "lsblk"

HOST=$(hostname)
REPORT=""

# Вспомогательная функция для получения атрибута
get_attr() {
    # $1=Output, $2=ID
    echo "$1" | awk -v id="$2" '$1 == id {print $10; exit}' | sed 's/^0*//' | awk '{if($1=="") print 0; else print $1}'
}

# Ищем физические диски (sdX, nvmeX)
DISKS=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}')

for disk in $DISKS; do
    DISK_ISSUES=""
    
    # 1. Health Check
    HEALTH=$(smartctl -H "$disk" 2>/dev/null | grep -i "result" | awk -F: '{print $2}' | xargs) || HEALTH="UNKNOWN"
    
    if [[ "$HEALTH" != "PASSED" && "$HEALTH" != "OK" ]]; then
        DISK_ISSUES+="🔴 Health Check Failed: ${HEALTH}\n"
    else
        # 2. Attribute Check (только если здоровье общее OK)
        ATTRS=$(smartctl -A "$disk" 2>/dev/null) || true
        
        # ID 5: Reallocated
        RSC=$(get_attr "$ATTRS" 5)
        if (( RSC > SMART_REALLOCATED_LIMIT )); then
            DISK_ISSUES+="⚠️ Reallocated Sectors (ID 5): ${RSC}\n"
        fi
        
        # ID 197: Pending
        PSC=$(get_attr "$ATTRS" 197)
        if (( PSC > SMART_PENDING_LIMIT )); then
            DISK_ISSUES+="⚠️ Pending Sectors (ID 197): ${PSC}\n"
        fi
    fi

    # Если есть проблемы по этому диску, добавляем в общий отчет
    if [[ -n "$DISK_ISSUES" ]]; then
        REPORT+="💾 *Disk ${disk}*:\n${DISK_ISSUES}\n"
    fi
done

if [[ -n "$REPORT" ]]; then
    MSG=$(cat <<EOF
🔧 *S.M.A.R.T Alert: ${HOST}*

${REPORT}
EOF
)
    send_telegram "$MSG"
    log_msg "ALERT: SMART errors detected."
fi

exit 0