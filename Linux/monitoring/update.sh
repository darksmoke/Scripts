#!/bin/bash
# /opt/monitoring/update.sh
# v.1.5 - Telegram alert on failed update; download to file + syntax check
#
# Скрипт запускает обновление и добавляет временные метки (Timestamp)
# ко всем строкам лога.
set -uo pipefail

# Копия вывода этого запуска — чтобы при сбое переслать причину в Telegram
RUN_LOG=$(mktemp)
trap 'rm -f "$RUN_LOG"' EXIT

# === Функция добавления времени ===
add_timestamp() {
    # Читаем поток построчно и добавляем дату
    while IFS= read -r line; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $line"
    done
}

# === Основной блок ===
# Весь вывод внутри { } перенаправляется в функцию add_timestamp
{
    echo "🔄 --- Start System Update ---"
    
    # Ссылка на install.sh (который теперь выполняет роль и установщика, и апдейтера)
    INSTALLER_URL="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring/install.sh"

    # Скачиваем install.sh во временный файл и запускаем только целиком
    # скачанный и синтаксически валидный. Раньше было `curl | bash`: при
    # обрыве bash исполнял половину скрипта, а без -f при ошибке GitHub —
    # HTML-страницу ошибки.
    TMP_INSTALLER=$(mktemp)
    trap 'rm -f "$TMP_INSTALLER"' EXIT
    if ! curl -fsSL --max-time 60 "$INSTALLER_URL" -o "$TMP_INSTALLER"; then
        echo "❌ ERROR: Failed to download install.sh."
        exit 1
    fi
    if ! bash -n "$TMP_INSTALLER"; then
        echo "❌ ERROR: install.sh has syntax errors, update skipped."
        exit 1
    fi

    if bash "$TMP_INSTALLER"; then
        echo "✅ Update process finished successfully."
    else
        echo "❌ ERROR: Update failed."
        exit 1
    fi

} 2>&1 | add_timestamp | tee "$RUN_LOG"
# 2>&1 означает: перенаправить и ошибки, и стандартный вывод в timestamp
UPDATE_RC=${PIPESTATUS[0]}

# === Уведомление о результате ===
# Ночью обновление идёт из cron без человека: о сбое должен узнать Telegram,
# иначе сервер молча остаётся на старой версии. Не глушится окном
# обслуживания (4-й аргумент "1"): обновление само идёт ночью, в 04:00.
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
if [[ -f "${SCRIPT_DIR}/utils.sh" ]]; then
    source "${SCRIPT_DIR}/utils.sh"
    HOST=$(hostname)
    if (( UPDATE_RC != 0 )); then
        # Последние строки вывода без метки времени ("YYYY-MM-DD HH:MM:SS - ")
        DETAILS=$(tail -n 5 "$RUN_LOG" | cut -c 23-)
        MSG=$(cat <<EOF
⚠️ *Не удалось обновить мониторинг: ${HOST}*
Скрипты остались на прошлой версии.
\`\`\`
${DETAILS}
\`\`\`
Полный лог: /var/log/monitoring_update.log
EOF
)
        manage_alert "monitoring_update" "ERROR" "$MSG" "1"
    else
        manage_alert "monitoring_update" "OK" ""
    fi
fi

exit "$UPDATE_RC"
