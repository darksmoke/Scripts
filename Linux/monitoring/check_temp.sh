#!/bin/bash
#
# Скрипт для проверки температуры компонентов системы
# и отправки уведомления в Telegram.
# release 1.1
#

# Строгий режим: выход при ошибке, при использовании необъявленной переменной
set -euo pipefail

# --- Инициализация ---

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

source "${SCRIPT_DIR}/config.ini"
source "${SCRIPT_DIR}/secrets.ini"

# Загружаем библиотеку отправки
source "${SCRIPT_DIR}/send_telegram.sh"

# --- Основная логика ---

# Проверяем, существует ли утилита 'sensors'
if ! command -v sensors &> /dev/null; then
    echo "INFO: Команда 'sensors' не найдена. Установите 'lm-sensors'. Проверка не выполняется."
    exit 0
fi

echo "Начало проверки температуры..."

# Переменные для сбора информации о перегревах
CRITICAL_ALERTS=""
WARNING_ALERTS=""

#
# ИСПРАВЛЕНИЕ ЗДЕСЬ: Используем надежную команду 'sed' для парсинга вывода 'sensors'
# в чистый формат 'ИмяДатчика:Температура'.

SENSORS_DATA=$(sensors | sed -n -E 's/^(.*[^[:space:]]):\s+\+([0-9.]+).*/\1:\2/p')


if [[ -z "$SENSORS_DATA" ]]; then
    echo "INFO: Не удалось получить данные о температуре от утилиты 'sensors'."
    exit 0
fi

while IFS=':' read -r SENSOR_NAME TEMP; do
    # Убираем дробную часть для целочисленного сравнения
    TEMP_INT=${TEMP%.*}
    
    echo "  - Проверка датчика: ${SENSOR_NAME} | Температура: ${TEMP}°C"

    # Сначала проверяем на CRITICAL, потом на WARNING
    if (( TEMP_INT >= TEMP_THRESHOLD_CRITICAL )); then
        CRITICAL_ALERTS+="🔥 *${SENSOR_NAME}:* \`${TEMP}°C\` (Порог: ${TEMP_THRESHOLD_CRITICAL}°C)\n"
    elif (( TEMP_INT >= TEMP_THRESHOLD_WARNING )); then
        WARNING_ALERTS+="⚠️ *${SENSOR_NAME}:* \`${TEMP}°C\` (Порог: ${TEMP_THRESHOLD_WARNING}°C)\n"
    fi
done <<< "$SENSORS_DATA"


# Если были собраны какие-либо оповещения, формируем и отправляем одно общее сообщение
if [[ -n "$CRITICAL_ALERTS" || -n "$WARNING_ALERTS" ]]; then
    HOST=$(hostname)
    TIME=$(date '+%Y-%m-%d %H:%M:%S')

    MSG=$(cat <<EOF
🌡️ *Обнаружен перегрев компонентов на сервере: ${HOST}* 🌡️

🕒 *Время:* ${TIME}

*Критические превышения:*
${CRITICAL_ALERTS:-Нет}

*Предупреждения:*
${WARNING_ALERTS:-Нет}
EOF
)

    echo "!!! ОБНАРУЖЕН ПЕРЕГРЕВ! Отправка уведомления в Telegram..."
    send_telegram "$MSG"
    echo "Уведомление отправлено."
else
    echo "Температура всех компонентов в норме."
fi

exit 0
