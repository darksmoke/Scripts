#!/bin/bash
#
# Скрипт для проверки загрузки дисковой подсистемы (IO Wait)
# и отправки уведомления в Telegram.
# v.1.0
#

# Строгий режим: выход при ошибке, при использовании необъявленной переменной
set -euo pipefail

# --- Инициализация ---

# Определяем абсолютный путь к директории со скриптом
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="${SCRIPT_DIR}/config.ini"

# Проверяем наличие файла конфигурации
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ОШИБКА: Файл конфигурации '${CONFIG_FILE}' не найден!" >&2
  exit 1
fi

# Проверяем наличие команды iostat
if ! command -v iostat &> /dev/null; then
    echo "ОШИБКА: Команда 'iostat' не найдена. Установите пакет 'sysstat'." >&2
    exit 1
fi

# Загружаем переменные из config.ini и библиотеку отправки
source "$CONFIG_FILE"
source "${SCRIPT_DIR}/send_telegram.sh"


# --- Основная логика ---

echo "Начало проверки IO Wait..."

# Получаем значение %iowait.
# 'iostat -c 1 2' делает 2 замера с интервалом в 1 секунду.
# Первый замер - среднее с момента загрузки (игнорируем его с помощью tail -n 1).
# Второй замер - среднее за последнюю секунду (то, что нам нужно).
# awk '{print $4}' извлекает 4-ю колонку (%iowait).
# LC_ALL=C - для унификации вывода iostat (чтобы точка всегда была точкой).
CURRENT_IOWAIT=$(LC_ALL=C iostat -c 1 2 | tail -n 1 | awk '{print $4}')

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
