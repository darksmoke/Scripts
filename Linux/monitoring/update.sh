#!/bin/bash
# /opt/monitoring/update.sh
# v.1.4 - download to file + syntax check instead of curl | bash
#
# Скрипт запускает обновление и добавляет временные метки (Timestamp)
# ко всем строкам лога.
set -uo pipefail

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

} 2>&1 | add_timestamp
# 2>&1 означает: перенаправить и ошибки, и стандартный вывод в timestamp
