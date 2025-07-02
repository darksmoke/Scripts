#!/bin/bash
#
# Скрипт для проверки свободного места на дисках и отправки уведомления в Telegram.
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

echo "Начало проверки свободного места на дисках..."
echo "Порог свободного места: ${DISK_FREE_SPACE_THRESHOLD}%"
echo "Исключения: ${DISK_EXCLUDE_LIST}"

HOST=$(hostname)

# Используем df с кастомным выводом для надежности и простоты парсинга.
# --output=source,pcent,avail,size,target,fstype
# pcent - процент использования (с символом %)
# avail - доступно в байтах
# size - общий размер в байтах
# target - точка монтирования
# fstype - тип файловой системы
# --local - показывать только локальные файловые системы
df --local --output=pcent,avail,size,target,fstype | tail -n +2 | while read -r line; do
  
  # Разбираем строку на переменные
  PERCENT_USED_STR=$(echo "$line" | awk '{print $1}')
  AVAIL_KB=$(echo "$line" | awk '{print $2}')
  SIZE_KB=$(echo "$line" | awk '{print $3}')
  MOUNT_POINT=$(echo "$line" | awk '{print $4}')
  FS_TYPE=$(echo "$line" | awk '{print $5}')
  
  # Удаляем символ '%' из процентов
  PERCENT_USED=${PERCENT_USED_STR//%}
  
  # --- Проверка исключений ---
  IS_EXCLUDED=false
  for excluded_item in $DISK_EXCLUDE_LIST; do
    # Проверяем совпадение по типу ФС или по точке монтирования
    if [[ "$FS_TYPE" == "$excluded_item" ]] || [[ "$MOUNT_POINT" == "$excluded_item" ]]; then
      echo "  - [ИСКЛЮЧЕНО] Раздел ${MOUNT_POINT} (тип: ${FS_TYPE}) в списке исключений."
      IS_EXCLUDED=true
      break
    fi
  done
  
  if [[ "$IS_EXCLUDED" == true ]]; then
    continue # Переходим к следующему разделу
  fi
  # --- Конец проверки исключений ---
  
  # Вычисляем процент свободного места
  PERCENT_FREE=$((100 - PERCENT_USED))
  
  echo "  - Проверка раздела: ${MOUNT_POINT} | Использовано: ${PERCENT_USED}% | Свободно: ${PERCENT_FREE}%"

  # Сравниваем процент свободного места с порогом
  if (( PERCENT_FREE < DISK_FREE_SPACE_THRESHOLD )); then
    
    # Конвертируем килобайты в человекочитаемый формат для красивого сообщения
    AVAIL_HUMAN=$(numfmt --to=iec-i --suffix=B --format="%.1f" "$AVAIL_KB")
    SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B --format="%.1f" "$SIZE_KB")
    TIME=$(date '+%Y-%m-%d %H:%M:%S')

    MSG=$(cat <<EOF
💽 *Критически мало места на диске: ${HOST}* 💽

🕒 *Время:* ${TIME}
💾 *Раздел:* \`${MOUNT_POINT}\`
📉 *Свободно:* ${PERCENT_FREE}% (${AVAIL_HUMAN})
💿 *Общий размер:* ${SIZE_HUMAN}

Пожалуйста, освободите место на диске.
EOF
)

    echo "!!! ПРЕВЫШЕНИЕ ПОРОГА на ${MOUNT_POINT}. Отправка уведомления в Telegram..."
    send_telegram "$MSG"
    echo "Уведомление отправлено."
  fi
done

echo "Проверка дискового пространства завершена."
exit 0
