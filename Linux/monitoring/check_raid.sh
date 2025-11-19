#!/bin/bash
# /opt/monitoring/check_raid.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

if ! command -v mdadm &> /dev/null; then
    # Тихо выходим, если нет mdadm, пишем в лог раз в сутки (опционально)
    exit 0
fi

HOST=$(hostname)
RAID_DEVICES=$(grep '^md' /proc/mdstat | awk '{print "/dev/"$1}') || true

if [[ -z "$RAID_DEVICES" ]]; then
    exit 0
fi

PROBLEM_REPORTS=""

for device in $RAID_DEVICES; do
    # Получаем детальный статус
    DEVICE_STATUS=$(mdadm --detail "$device")
    
    # Ищем состояния НЕ clean и НЕ active
    PROBLEMS=$(echo "$DEVICE_STATUS" | grep 'State :' | grep -v -E 'clean|active$') || true

    if [[ -n "$PROBLEMS" ]]; then
        PROBLEM_REPORTS+="🔹 *Device:* \`${device}\`\n\`\`\`\n${PROBLEMS}\n\`\`\`\n"
    fi
done

if [[ -n "$PROBLEM_REPORTS" ]]; then
    MSG=$(cat <<EOF
🚨 *RAID Issue Detected: ${HOST}*

${PROBLEM_REPORTS}
Check \`cat /proc/mdstat\` immediately!
EOF
)
    send_telegram "$MSG"
    log_msg "ALERT: RAID issues detected."
fi

exit 0