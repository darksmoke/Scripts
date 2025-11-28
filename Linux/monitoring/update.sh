#!/bin/bash
# /opt/monitoring/update.sh
# v.1.3
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

    # Скачиваем и запускаем install.sh
    # Флаг -sS убирает прогресс-бар curl, чтобы не мусорить в логах
    if curl -sS "$INSTALLER_URL" | bash; then
        echo "✅ Update process finished successfully."
    else
        echo "❌ ERROR: Update failed."
        exit 1
    fi

} 2>&1 | add_timestamp
# 2>&1 означает: перенаправить и ошибки, и стандартный вывод в timestamp
