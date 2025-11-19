#!/bin/bash
# /opt/monitoring/update.sh
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/config.sh"

echo "Start update..."

# Переходим в папку
cd "$INSTALL_DIR"

# Список файлов для обновления (исключая config.sh, чтобы не затереть токены)
FILES_TO_UPDATE=("utils.sh" "check_cpu.sh" "check_disk.sh" "check_ram.sh" "check_smart.sh" "check_iowait.sh" "check_uptime.sh" "install.sh")

BASE_URL="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring"

for file in "${FILES_TO_UPDATE[@]}"; do
    if curl -fsSL "${BASE_URL}/${file}" -o "${file}.tmp"; then
        mv "${file}.tmp" "${file}"
        chmod +x "${file}"
        # Снимаем исполнение с библиотек
        [[ "$file" == "utils.sh" ]] && chmod -x "$file"
        echo "Updated: $file"
    else
        echo "Error updating: $file"
        rm -f "${file}.tmp"
    fi
done

echo "Update finished."