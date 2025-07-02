#!/bin/bash
#
# Скрипт для проверки загрузки дисковой подсистемы (IO Wait)
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

# Проверяем наличие команды iostat
if ! command -v iostat &> /dev/null; then
    echo "ОШИБКА: Команда 'iostat' не найдена. Установите пакет 'sysstat'." >&2
    exit 1
fi

echo "Начало проверки IO Wait..."

#
# ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ: Используем шаблон awk, который ищет строки,
# начинающиеся с пробелов, а затем с цифры. Это соответствует вашему выводу.
#
CURRENT_IOWAIT=$(LC_ALL=C iostat -c 2 3 | awk '/^[[:space:]]+[0-9]/ { S = $0 } END { print S }' | awk '{print $4}')

# Дополнительная проверка, что переменная не пустая
if [[ -z "$CURRENT_IOWAIT" ]]; then
    echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось получить значение IO Wait от iostat." >&2
    echo "--- ОТЛАДОЧНЫЙ ВЫВОД iostat ---"
    LC_ALL=C iostat -c 2 3
    echo "---------------------------------"
    exit 1
fi

echo "Данные для проверки:"
echo "  - Текущий IO Wait: ${CURRENT_IOWAIT}%"
echo "  - Порог срабатывания: ${IO_WAIT_THRESHOLD}%"

# Сравниваем текущее значение с порогом, используя 'bc'
IS_OVERLOADED=$(echo "${CURRENT_IOWAIT} > ${IO_WAIT_THRESHOLD}" | bc -l)

if [[ "$IS_OVERLOADED" -eq 1 ]]; then
  # Нагрузка превышена, формируем и отправляем сообщение
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')

  MSG=$(cat <<EOF
⚡️ *Высокий IO Wait на сервере: ${HOST}* ⚡️

🕒 *Время:* ${TIME}
📈 *Текущий IO Wait:* \`${CURRENT_IOWAIT}%\`
📊 *Установленный порог:* \`${IO_WAIT_THRESHOLD}%\`

Это может указывать на проблемы с дисковой подсистемой (медленный диск, большая очередь запросов).
EOF
)

  echo "ПРЕВЫШЕНИЕ ПОРОГА! Отправка уведомления в Telegram..."
  send_telegram "$MSG"
  echo "Уведомление отправлено."

else
  # Нагрузка в норме
  echo "IO Wait в пределах нормы."
fi

exit 0
