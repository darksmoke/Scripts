#!/bin/bash
# /opt/monitoring/update.sh
set -euo pipefail

# URL установщика
INSTALLER_URL="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring/install.sh"

echo "🔄 Запуск обновления системы мониторинга..."

if curl -sS "$INSTALLER_URL" | bash; then
    echo "✅ Система успешно обновлена до актуальной версии."
else
    echo "❌ Ошибка при обновлении."
    exit 1
fi
