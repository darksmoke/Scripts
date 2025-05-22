#!/bin/bash
CONFIG_FILE="config.ini"
source send_telegram.sh

THRESHOLD=75

TEMP=$(sensors | grep -E 'Core 0|Package id 0' | head -n 1 | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1)

if [[ $TEMP -gt $THRESHOLD ]]; then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')
  MSG="🔥 *$HOST*\n🕒 $TIME\nТемпература CPU: ${TEMP}°C"
  send_telegram "$MSG"
fi
