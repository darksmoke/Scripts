#!/bin/bash
# v3
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/send_telegram.sh"
source "$SCRIPT_DIR/config.ini"

WARNING_TEMP=80
CRITICAL_TEMP=100

# Получаем только текущие температуры (первая встречающаяся температура в строке)
TEMPS=$(sensors | grep -oP ':\s+\+\K[0-9.]+(?=°C)' )

for TEMP in $TEMPS; do
    TEMP_INT=${TEMP%.*}  # убираем дробную часть
    if [[ "$TEMP_INT" -ge $CRITICAL_TEMP ]]; then
        MESSAGE="🔥 CRITICAL: Temperature is ${TEMP}°C"
        bash "$(dirname "$0")/send_telegram.sh" "$MESSAGE"
    elif [[ "$TEMP_INT" -ge $WARNING_TEMP ]]; then
        MESSAGE="⚠️ WARNING: Temperature is ${TEMP}°C"
        bash "$(dirname "$0")/send_telegram.sh" "$MESSAGE"
    fi
done
