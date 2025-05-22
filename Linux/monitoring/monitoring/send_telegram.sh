#!/bin/bash
# send_telegram.sh
# Загружается в каждый мониторинг-скрипт через `source`

CONFIG_FILE="config.ini"

TOKEN=$(grep -E '^TOKEN=' "$CONFIG_FILE" | cut -d'=' -f2)
CHAT_ID=$(grep -E '^CHAT_ID=' "$CONFIG_FILE" | cut -d'=' -f2)

send_telegram() {
  local MESSAGE="$1"
  curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${MESSAGE}" \
    -d parse_mode="Markdown"
}
