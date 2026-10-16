#!/bin/bash
# /opt/monitoring/check_reboot.sh
# v.1.1 - для Debian/RHEL: сравнение запущенного ядра с последним установленным
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

HOST=$(hostname)
REBOOT_FLAG="/var/run/reboot-required"
PKGS_FILE="/var/run/reboot-required.pkgs"
ALERT_ID="system_reboot_required"
REASONS=""

if [[ -f "$REBOOT_FLAG" ]]; then
    PKGS="Пакеты не указаны"
    if [[ -f "$PKGS_FILE" ]]; then
        # Читаем пакеты, заменяем перенос строки на запятую
        PKGS=$(paste -sd, "$PKGS_FILE")
    fi
    REASONS+="*Пакеты:* \`${PKGS}\`\n"
fi

# /var/run/reboot-required создаёт update-notifier (Ubuntu); на Debian и RHEL
# его обычно нет, и после обновления ядра алерт не приходил. Поэтому
# дополнительно сравниваем запущенное ядро с самым новым в /boot.
RUNNING=$(uname -r)
NEWEST=$(ls /boot/vmlinuz-* 2>/dev/null | sed 's#^/boot/vmlinuz-##' | grep -v rescue | sort -V | tail -1)
if [[ -n "$NEWEST" && "$NEWEST" != "$RUNNING" ]]; then
    REASONS+="*Ядро:* запущено \`${RUNNING}\`, установлено \`${NEWEST}\`\n"
fi

if [[ -n "$REASONS" ]]; then
    MSG=$(cat <<EOF
*Требуется перезагрузка: ${HOST}*
${REASONS}
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    # Если причин нет (сервер перезагрузили) — отправляем сигнал восстановления
    manage_alert "$ALERT_ID" "OK" ""
fi

exit 0
