#!/bin/bash
#
# Скрипт для проверки доступной оперативной памяти (RAM)
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

echo "Начало проверки доступной оперативной памяти..."

# Используем 'free -m' для получения данных в мегабайтах.
# Парсим строку 'Mem:', извлекая общий объем (total) и доступный (available).
# 'awk' позволяет сделать это в одну строку.
read -r TOTAL_MB AVAILABLE_MB <<< $(free -m | awk '/^Mem:/ {print $2, $7}')

# Рассчитываем процент доступной памяти
PERCENT_AVAILABLE=$(( 100 * AVAILABLE_MB / TOTAL_MB ))

echo "Данные для проверки:"
echo "  - Всего RAM: ${TOTAL_MB}MB"
echo "  - Доступно RAM: ${AVAILABLE_MB}MB (${PERCENT_AVAILABLE}%)"
echo "  - Порог срабатывания: ${RAM_AVAILABLE_THRESHOLD_PERCENT}%"

# Сравниваем процент доступной памяти с порогом
if (( PERCENT_AVAILABLE < RAM_AVAILABLE_THRESHOLD_PERCENT )); then
  # Памяти мало, формируем и отправляем сообщение
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')

  MSG=$(cat <<EOF
🧠 *Критически мало оперативной памяти на сервере: ${HOST}* 🧠

🕒 *Время:* ${TIME}
📉 *Доступно RAM:* ${PERCENT_AVAILABLE}% (${AVAILABLE_MB}MB)
💾 *Всего RAM:* ${TOTAL_MB}MB
📊 *Установленный порог:* ${RAM_AVAILABLE_THRESHOLD_PERCENT}%

Системе может скоро не хватить памяти для новых процессов.
EOF
)

  echo "!!! НИЗКИЙ УРОВЕНЬ ПАМЯТИ! Отправка уведомления в Telegram..."
  send_telegram "$MSG"
  echo "Уведомление отправлено."

else
  # Памяти достаточно
  echo "Уровень доступной памяти в норме."
fi

exit 0
