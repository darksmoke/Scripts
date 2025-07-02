#!/bin/bash
#
# Скрипт для проверки использования файла подкачки (SWAP)
# и отправки уведомления в Telegram.
# v.1.1
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

echo "Начало проверки использования SWAP..."

# Получаем данные по swap в мегабайтах.
# Парсим строку 'Swap:', извлекая общий объем (total) и использованный (used).
read -r TOTAL_MB USED_MB <<< $(free -m | awk '/^Swap:/ {print $2, $3}')

# Проверяем, существует ли SWAP в системе. Если total = 0, то его нет.
if (( TOTAL_MB == 0 )); then
    echo "INFO: SWAP не используется в системе. Проверка не выполняется."
    exit 0
fi

# Рассчитываем процент использования
PERCENT_USED=$(( 100 * USED_MB / TOTAL_MB ))

echo "Данные для проверки:"
echo "  - Всего SWAP: ${TOTAL_MB}MB"
echo "  - Использовано SWAP: ${USED_MB}MB (${PERCENT_USED}%)"
echo "  - Порог срабатывания: ${SWAP_USAGE_THRESHOLD_PERCENT}%"

# Сравниваем процент использования с порогом
if (( PERCENT_USED > SWAP_USAGE_THRESHOLD_PERCENT )); then
  # Использование превышает порог, формируем и отправляем сообщение
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')

  MSG=$(cat <<EOF
🔂 *Высокое использование SWAP на сервере: ${HOST}* 🔂

🕒 *Время:* ${TIME}
📈 *Использовано SWAP:* ${PERCENT_USED}% (${USED_MB}MB из ${TOTAL_MB}MB)
📊 *Установленный порог:* ${SWAP_USAGE_THRESHOLD_PERCENT}%

Активное использование SWAP может свидетельствовать о нехватке оперативной памяти и замедлении работы системы.
EOF
)

  echo "!!! ВЫСОКОЕ ИСПОЛЬЗОВАНИЕ SWAP! Отправка уведомления в Telegram..."
  send_telegram "$MSG"
  echo "Уведомление отправлено."

else
  # Использование в норме
  echo "Уровень использования SWAP в норме."
fi

exit 0
