#!/bin/bash
#
# Скрипт для проверки загрузки CPU (load average) и отправки уведомления в Telegram.
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

echo "Начало проверки загрузки CPU..."

# Получаем количество ядер процессора
CORES=$(nproc)
# Получаем 1-минутный load average (первое число из /proc/loadavg)
LOAD_AVG=$(awk '{print $1}' /proc/loadavg)

# Вычисляем пороговое значение load average на основе процента из конфига.
# Используем 'bc' для вычислений с плавающей точкой.
THRESHOLD_VALUE=$(echo "scale=2; ${CORES} * ${CPU_THRESHOLD_PERCENT} / 100" | bc)

echo "Данные для проверки:"
echo "  - Ядер: ${CORES}"
echo "  - Текущий Load Average (1 min): ${LOAD_AVG}"
echo "  - Порог срабатывания (%): ${CPU_THRESHOLD_PERCENT}%"
echo "  - Пороговое значение Load Average: ${THRESHOLD_VALUE}"

# Сравниваем текущую нагрузку с пороговой.
# '1' - если LOAD_AVG > THRESHOLD_VALUE, '0' - в противном случае.
IS_OVERLOADED=$(echo "${LOAD_AVG} > ${THRESHOLD_VALUE}" | bc)

if [[ "$IS_OVERLOADED" -eq 1 ]]; then
  # Нагрузка превышена, формируем и отправляем сообщение
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')

  MSG=$(cat <<EOF
🔥 *Высокая нагрузка на CPU: ${HOST}* 🔥

🕒 *Время:* ${TIME}
⚙️ *Ядер:* ${CORES}
📈 *Текущий Load Average:* \`${LOAD_AVG}\`
📊 *Порог срабатывания:* \`${THRESHOLD_VALUE}\` (>${CPU_THRESHOLD_PERCENT}%)

Нагрузка на процессор превысила норму.
EOF
)

  echo "ПРЕВЫШЕНИЕ ПОРОГА! Отправка уведомления в Telegram..."
  send_telegram "$MSG"
  echo "Уведомление отправлено."

else
  # Нагрузка в норме
  echo "Нагрузка на CPU в пределах нормы."
fi

exit 0
