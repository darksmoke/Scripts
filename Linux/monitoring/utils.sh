#!/bin/bash
# /opt/monitoring/utils.sh

source "$(dirname "$0")/config.sh"

mkdir -p "$STATE_DIR"

# Функция логирования
log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Базовая отправка (внутренняя функция)
_send_telegram_raw() {
    local message="$1"
    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
        log_msg "ERROR: Telegram credentials missing."
        return 1
    fi
    curl -sS --max-time 10 \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="Markdown" > /dev/null
}

# === УМНАЯ ФУНКЦИЯ УПРАВЛЕНИЯ АЛЕРТАМИ ===
# Использование: manage_alert "УникальныйID" "Статус(ERROR/OK)" "Текст ошибки"
manage_alert() {
    local ALERT_ID="$1"
    local STATUS="$2"
    local MSG_TEXT="$3"
    local STATE_FILE="${STATE_DIR}/${ALERT_ID}.lock"

    if [[ "$STATUS" == "ERROR" ]]; then
        # --- Сценарий: ОШИБКА ---
        
        if [[ -f "$STATE_FILE" ]]; then
            # Ошибка уже была зафиксирована ранее
            local LAST_ALERT_TIME
            LAST_ALERT_TIME=$(cat "$STATE_FILE")
            local CURRENT_TIME
            CURRENT_TIME=$(date +%s)
            local DIFF=$((CURRENT_TIME - LAST_ALERT_TIME))

            if (( DIFF > ALERT_MUTE_PERIOD )); then
                # Прошло достаточно времени для напоминания
                _send_telegram_raw "🔁 *Напоминание:* Проблема сохраняется!
$MSG_TEXT"
                echo "$CURRENT_TIME" > "$STATE_FILE"
                log_msg "REMINDER SENT: $ALERT_ID"
            else
                # Рано для повтора, молчим
                log_msg "MUTE: $ALERT_ID (Too soon to repeat)"
            fi
        else
            # Ошибка возникла впервые
            _send_telegram_raw "🔥 *Проблема обнаружена:*
$MSG_TEXT"
            date +%s > "$STATE_FILE"
            log_msg "NEW ALERT SENT: $ALERT_ID"
        fi

    elif [[ "$STATUS" == "OK" ]]; then
        # --- Сценарий: ВСЁ ХОРОШО ---
        
        if [[ -f "$STATE_FILE" ]]; then
            # Раньше была ошибка, теперь её нет -> RECOVERY
            local HOST
            HOST=$(hostname)
            _send_telegram_raw "✅ *Восстановление (${HOST}):*
Проблема с *${ALERT_ID}* решена."
            rm -f "$STATE_FILE"
            log_msg "RECOVERY SENT: $ALERT_ID"
        fi
        # Если файла нет и статус OK — просто ничего не делаем
    fi
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_msg "ERROR: Command '$1' not found."
        exit 1
    fi
}
