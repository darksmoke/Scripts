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
HAS_ERROR=0

get_attr() {
    echo "$1" | awk -v id="$2" '$1 == id {print $10; exit}' | sed 's/^0*//' | awk '{if($1=="") print 0; else print $1}'
}

DISKS=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}')

for disk in $DISKS; do
    DISK_ISSUES=""
    
    HEALTH=$(smartctl -H "$disk" 2>/dev/null | grep -i "result" | awk -F: '{print $2}' | xargs) || HEALTH="UNKNOWN"
    
    if [[ "$HEALTH" != "PASSED" && "$HEALTH" != "OK" ]]; then
        DISK_ISSUES+="🔴 Health Check Failed: ${HEALTH}\n"
    else
        ATTRS=$(smartctl -A "$disk" 2>/dev/null) || true
        
        RSC=$(get_attr "$ATTRS" 5)
        if (( RSC > SMART_REALLOCATED_LIMIT )); then
            DISK_ISSUES+="⚠️ Reallocated Sectors (ID 5): ${RSC}\n"
        fi
        
        PSC=$(get_attr "$ATTRS" 197)
        if (( PSC > SMART_PENDING_LIMIT )); then
            DISK_ISSUES+="⚠️ Pending Sectors (ID 197): ${PSC}\n"
        fi
    fi

    if [[ -n "$DISK_ISSUES" ]]; then
        REPORT+="💾 *Disk ${disk}*:\n${DISK_ISSUES}\n"
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
