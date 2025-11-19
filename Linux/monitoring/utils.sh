#!/bin/bash
# /opt/monitoring/utils.sh

source "$(dirname "$0")/config.sh"

# Функция логирования
log_msg() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

# Функция отправки в Telegram
send_telegram() {
    local message="$1"
    
    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
        log_msg "ERROR: Telegram credentials missing."
        return 1
    fi

    # Отправка с таймаутом 10 сек
    local response
    response=$(curl -sS --max-time 10 \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="Markdown" 2>&1)

    if [[ $? -ne 0 ]]; then
        log_msg "ERROR: Failed to send Telegram message. Curl output: $response"
    else
        log_msg "INFO: Notification sent."
    fi
}

# Проверка зависимостей
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_msg "ERROR: Command '$1' not found."
        exit 1
    fi
}