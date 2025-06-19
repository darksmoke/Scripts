#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/send_telegram.sh"
source "$SCRIPT_DIR/config.ini"

UPTIME_MINUTES=$(awk '{print int($1/60)}' /proc/uptime)

if [[ $UPTIME_MINUTES -lt 60 ]]; then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')
  MSG="⚠️ *$HOST*
  🕒 $TIME
  Перезагрузка менее часа назад (аптайм: ${UPTIME_MINUTES} мин)"
  send_telegram "$MSG"
fi
