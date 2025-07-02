#!/bin/bash
#
# Скрипт для безопасного обновления скриптов мониторинга.
# Не затрагивает файлы config.ini и secrets.ini.
# v.1.0
#
set -euo pipefail

# === Конфигурация ===
INSTALL_DIR="${1:-/root/scripts/monitoring}"
RAW_BASE="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring"
SCRIPTS=(
    send_telegram.sh check_cpu.sh check_ram.sh check_disk.sh
    check_iowait.sh check_uptime.sh check_raid.sh check_temp.sh
    check_swap.sh check_smart.sh
)

if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "❌ Директория ${INSTALL_DIR} не найдена. Сначала запустите install.sh."
    exit 1
fi

echo "🔄 Обновление скриптов в директории ${INSTALL_DIR}..."
cd "$INSTALL_DIR"

for script in "${SCRIPTS[@]}"; do
    echo "   - ${script}"
    curl -fsSL "${RAW_BASE}/${script}" -o "${script}"
    chmod +x "${script}"
done

echo "✅ Обновление завершено."
