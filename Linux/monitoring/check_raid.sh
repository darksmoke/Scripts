#!/bin/bash
# /opt/monitoring/check_raid.sh
# v.1.2 - Added ignore for 'checking' state
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

if ! command -v mdadm &> /dev/null; then
    exit 0
fi

HOST=$(hostname)
RAID_DEVICES=$(grep '^md' /proc/mdstat | awk '{print "/dev/"$1}') || true

if [[ -z "$RAID_DEVICES" ]]; then
    exit 0
fi

PROBLEM_REPORTS=""
HAS_ERROR=0

for device in $RAID_DEVICES; do
    DEVICE_STATUS=$(mdadm --detail "$device")
    
    # Игнорируем штатные статусы: clean, active, а также процесс проверки (checking)
    PROBLEMS=$(echo "$DEVICE_STATUS" | grep 'State :' | grep -v -E '(clean|active)(, checking)?[[:space:]]*$') || true

    if [[ -n "$PROBLEMS" ]]; then
        PROBLEM_REPORTS+="🔹 *Device:* \`${device}\`\n\`\`\`\n${PROBLEMS}\n\`\`\`\n"
        HAS_ERROR=1
    fi
done

ALERT_ID="raid_health"

if [[ "$HAS_ERROR" -eq 1 ]]; then
    MSG=$(cat <<EOF
🚨 *Проблемы с RAID: ${HOST}*
${PROBLEM_REPORTS}
Проверьте \`cat /proc/mdstat\`
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
