#!/bin/bash
#
# v.0.2
#

CONFIG_FILE="config.ini"
THRESHOLD=10  # Порог свободного места в %

# Пути монтирования, которые нужно исключить (через пробел)
EXCLUDE_MOUNTS="/snap"

# Проверка конфигурационного файла
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Файл конфигурации $CONFIG_FILE не найден!"
  exit 1
fi

# Загрузка переменных из config.ini
TOKEN=$(grep -E '^TOKEN=' "$CONFIG_FILE" | cut -d'=' -f2)
CHAT_ID=$(grep -E '^CHAT_ID=' "$CONFIG_FILE" | cut -d'=' -f2)

if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then
  echo "Ошибка: пустые TOKEN или CHAT_ID"
  exit 1
fi

# Функция проверки, входит ли элемент в список исключений
is_excluded() {
  local mount_point=$1
  for excl in $EXCLUDE_MOUNTS; do
    if [[ "$mount_point" == "$excl" ]] || [[ "$mount_point" == "$excl/"* ]]; then
      return 0
    fi
  done
  return 1
}

# Обход всех файловых систем
df -hP | awk 'NR>1' | while read -r line; do
  USE_PERCENT=$(echo "$line" | awk '{print $(NF-1)}' | tr -d '%')
  AVAIL=$(echo "$line" | awk '{print $(NF-2)}')  # доступно
  TOTAL=$(echo "$line" | awk '{print $(2)}')     # всего
  MOUNT=$(echo "$line" | awk '{print $NF}')

  # Пропускаем исключённые монтирования
  if is_excluded "$MOUNT"; then
    continue
  fi

  if (( USE_PERCENT > (100 - THRESHOLD) )); then
    HOST=$(hostname)
    TIME=$(date '+%Y-%m-%d %H:%M:%S')

    MESSAGE="⚠️ *${HOST}*
🕒 ${TIME}
На разделе \`${MOUNT}\` осталось *${AVAIL}* из *${TOTAL}* свободного места"

    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
      -d chat_id="${CHAT_ID}" \
      -d text="${MESSAGE}" \
      -d parse_mode="Markdown"
  fi
done
