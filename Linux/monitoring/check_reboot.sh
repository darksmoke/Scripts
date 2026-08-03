#!/bin/bash
# /opt/monitoring/check_reboot.sh
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

HOST=$(hostname)
REBOOT_FLAG="/var/run/reboot-required"
PKGS_FILE="/var/run/reboot-required.pkgs"
ALERT_ID="system_reboot_required"

if [[ -f "$REBOOT_FLAG" ]]; then
    PKGS="Пакеты не указаны"
    if [[ -f "$PKGS_FILE" ]]; then
        # Читаем пакеты, заменяем перенос строки на запятую
        PKGS=$(paste -sd, "$PKGS_FILE")
    fi

    MSG=$(cat <<EOF
*Требуется перезагрузка: ${HOST}*
*Пакеты:* \`${PKGS}\`
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    # Если файл пропал (сервер перезагрузили) — отправляем сигнал восстановления
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
