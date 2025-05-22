#!/bin/bash

CONFIG_FILE="config.ini"
source send_telegram.sh

THRESHOLD=60  # порог в процентах

# Получаем данные по swap в мегабайтах
read -r TOTAL USED FREE <<< $(free -m | awk '/Swap:/ {print $2, $3, $4}')

# Если нет свопа — выходим
if (( TOTAL == 0 )); then
  exit 0
fi

# Считаем процент использования
PERCENT=$(( 100 * USED / TOTAL ))

# Проверяем порог
if (( PERCENT > THRESHOLD )); then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')

  MESSAGE="⚠️ *${HOST}*
🕒 ${TIME}
Swap занят на *${PERCENT}%* (*${USED}МБ* из *${TOTAL}МБ*)"

  send_telegram "$MESSAGE"
fi
