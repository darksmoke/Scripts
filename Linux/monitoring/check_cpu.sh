#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/send_telegram.sh"
source "$SCRIPT_DIR/config.ini"


THRESHOLD=80
LOAD=$(awk '{print $1*100}' < /proc/loadavg | cut -d'.' -f1)
CORES=$(nproc)
LIMIT=$((CORES * THRESHOLD))

if [[ $LOAD -gt $LIMIT ]]; then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')
  MSG="⚠️ *$HOST*
  🕒 $TIME
  CPU перегружен: loadavg=$LOAD%, ядер=$CORES"
  send_telegram "$MSG"
fi
