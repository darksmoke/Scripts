#!/bin/bash
#
# Скрипт для проверки состояния программных RAID-массивов (mdadm)
# и отправки уведомления в Telegram в случае проблем.
# v.1.0
#

# Строгий режим: выход при ошибке, при использовании необъявленной переменной
set -euo pipefail

# --- Инициализация ---

# Определяем абсолютный путь к директории со скриптом
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="${SCRIPT_DIR}/config.ini"

# Проверяем, существует ли mdadm в системе. Если нет, то и проверять нечего.
if ! command -v mdadm &> /dev/null; then
    echo "INFO: Команда 'mdadm' не найдена. Проверка RAID не выполняется."
    exit 0
fi

# Проверяем наличие файла конфигурации
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ОШИБКА: Файл конфигурации '${CONFIG_FILE}' не найден!" >&2
  exit 1
fi

# Загружаем переменные из config.ini и библиотеку отправки
source "$CONFIG_FILE"
source "${SCRIPT_DIR}/send_telegram.sh"


# --- Основная логика ---

echo "Начало проверки состояния программных RAID-массивов..."

# Получаем список всех активных md-устройств
RAID_DEVICES=$(cat /proc/mdstat | grep '^md' | awk '{print "/dev/"$1}')

if [[ -z "$RAID_DEVICES" ]]; then
    echo "INFO: Активные RAID-массивы не найдены."
    exit 0
fi

# Флаг для отслеживания общего состояния
OVERALL_STATUS_OK=true
# Переменная для сбора проблемных отчетов
PROBLEM_REPORTS=""

for device in $RAID_DEVICES; do
    echo "  - Проверка устройства: ${device}"
    
    # Используем 'mdadm --detail' для получения статуса.
    # Ищем строки, содержащие 'State : active, degraded', 'State : active, recovering', и т.д.
    # 'State : clean' или 'State : active' - это норма.
    # 'grep -v' исключает нормальные состояния.
    DEVICE_STATUS=$(mdadm --detail "$device")
    
    # Ищем любой статус, который не является 'clean' или 'active' без доп. слов.
    # '|| true' предотвращает выход по 'set -e', если grep ничего не найдет.
    PROBLEMS=$(echo "$DEVICE_STATUS" | grep 'State :' | grep -v -E 'clean|active$') || true

    if [[ -n "$PROBLEMS" ]]; then
        OVERALL_STATUS_OK=false
        echo "!!! ОБНАРУЖЕНА ПРОБЛЕМА с ${device}!"
        
        # Собираем полный отчет для отправки в Telegram
        PROBLEM_REPORTS+=$(cat <<EOF
---
Устройство: \`${device}\`
Состояние:
\`\`\`
${DEVICE_STATUS}
\`\`\`
---
EOF
)
    else
        echo "    Статус: OK"
    fi
done

# Если были обнаружены проблемы, отправляем одно большое уведомление
if [[ "$OVERALL_STATUS_OK" == false ]]; then
    HOST=$(hostname)
    TIME=$(date '+%Y-%m-%d %H:%M:%S')

    MSG=$(cat <<EOF
🚨 *Обнаружены проблемы с RAID на сервере: ${HOST}* 🚨

🕒 *Время:* ${TIME}

Обнаружены массивы в состоянии, отличном от 'clean' (например, degraded, resyncing).
Требуется немедленное вмешательство!

*Детальная информация:*
${PROBLEM_REPORTS}
EOF
)

    echo "Отправка уведомления о проблемах с RAID в Telegram..."
    send_telegram "$MSG"
    echo "Уведомление отправлено."
else
    echo "Все RAID-массивы в порядке."
fi

exit 0
