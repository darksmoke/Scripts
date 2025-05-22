#!/bin/bash
CONFIG_FILE="config.ini"
source send_telegram.sh

UPTIME_MINUTES=$(awk '{print int($1/60)}' /proc/uptime)

if [[ $UPTIME_MINUTES -lt 60 ]]; then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')
  MSG="⚠️ *$HOST*\n🕒 $TIME\nПерезагрузка менее часа назад (аптайм: ${UPTIME_MINUTES} мин)"
  send_telegram "$MSG"
fi
