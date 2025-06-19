#!/bin/bash
#
# v.0.1
#
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/send_telegram.sh"
source "$SCRIPT_DIR/config.ini"

CONFIG_FILE="config.ini"

# Пороговые значения
MAX_REALLOCATED=5
MAX_UNCORRECTABLE=0
MAX_PENDING=0
MAX_TIMEOUT=0

# Загрузка конфигурации
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Файл $CONFIG_FILE не найден!"
  exit 1
fi

TOKEN=$(grep -E '^TOKEN=' "$CONFIG_FILE" | cut -d'=' -f2)
CHAT_ID=$(grep -E '^CHAT_ID=' "$CONFIG_FILE" | cut -d'=' -f2)

if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then
  echo "Ошибка: пустые TOKEN или CHAT_ID"
  exit 1
fi

HOST=$(hostname)
TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Получение списка дисков (только physical)
DISKS=$(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" {print $1}')

for DISK in $DISKS; do
  OUTPUT=$(smartctl -A /dev/$DISK)

  # Извлекаем параметры
  REALLOCATED=$(echo "$OUTPUT" | awk '$1 == 5 {print $10}')
  UNCORRECTABLE=$(echo "$OUTPUT" | awk '$1 == 198 {print $10}')
  PENDING=$(echo "$OUTPUT" | awk '$1 == 197 {print $10}')
  TIMEOUT=$(echo "$OUTPUT" | awk '$1 == 188 {print $10}')
  REPORTED=$(echo "$OUTPUT" | awk '$1 == 187 {print $10}')

  WARNINGS=()

  [[ "$REALLOCATED" -gt $MAX_REALLOCATED ]] && WARNINGS+=("🔴 Reallocated_Sector_Ct: $REALLOCATED")
  [[ "$UNCORRECTABLE" -gt $MAX_UNCORRECTABLE ]] && WARNINGS+=("🔴 Offline_Uncorrectable: $UNCORRECTABLE")
  [[ "$PENDING" -gt $MAX_PENDING ]] && WARNINGS+=("🔴 Current_Pending_Sector: $PENDING")
  [[ "$TIMEOUT" -gt $MAX_TIMEOUT ]] && WARNINGS+=("🔴 Command_Timeout: $TIMEOUT")
  [[ "$REPORTED" -gt 0 ]] && WARNINGS+=("🔴 Reported_Uncorrect: $REPORTED")

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    MESSAGE="⚠️ *$HOST*
🕒 $TIME
SMART-проблемы на диске */dev/$DISK*:
$(printf '%s\n' "${WARNINGS[@]}")"

    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
      -d chat_id="${CHAT_ID}" \
      -d text="$MESSAGE" \
      -d parse_mode="Markdown"
  fi
done
