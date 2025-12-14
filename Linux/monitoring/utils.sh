#!/bin/bash
# /opt/monitoring/utils.sh
# v.1.5 - Added Global Maintenance Window logic

source "$(dirname "$0")/config.sh"

mkdir -p "$STATE_DIR"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

_send_telegram_raw() {
    local message="$1"
    if [[ -z "${BOT_TOKEN:-}" || -z "${CHAT_ID:-}" ]]; then
        log_msg "ERROR: Telegram credentials missing."
        return 1
    fi
    curl -sS --max-time 10 \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="Markdown" > /dev/null
}

# Функция проверки: находимся ли мы сейчас в окне обслуживания?
is_maintenance_now() {
    # Если переменные не заданы — обслуживания нет
    if [[ -z "${GLOBAL_MNT_START:-}" || -z "${GLOBAL_MNT_END:-}" ]]; then
        return 1 # False (не в обслуживании)
    fi

    local CUR_HOUR=$((10#$(date +%H)))
    local START=$((10#$GLOBAL_MNT_START))
    local END=$((10#$GLOBAL_MNT_END))

    if (( START < END )); then
        # Пример: с 02 до 06
        if (( CUR_HOUR >= START && CUR_HOUR < END )); then return 0; fi
    else
        # Пример: с 23 до 08 (переход через полночь)
        if (( CUR_HOUR >= START || CUR_HOUR < END )); then return 0; fi
    fi

    return 1 # False
}

manage_alert() {
    local ALERT_ID="$1"
    local STATUS="$2"
    local MSG_TEXT="$3"
    local STATE_FILE="${STATE_DIR}/${ALERT_ID}.lock"

    if [[ "$STATUS" == "ERROR" ]]; then
        
        # === ПРОВЕРКА ГЛОБАЛЬНОГО МЕЙТЕНАНСА ===
        if is_maintenance_now; then
            # Если сейчас ночь обслуживания — мы просто пишем в лог и НЕ шлем алерт.
            # Мы даже не создаем Lock-файл, чтобы после окончания обслуживания
            # скрипт честно прислал "New Alert", если проблема останется.
            log_msg "SILENCE: $ALERT_ID suppressed due to Global Maintenance."
            return
        fi
        # ========================================

        if [[ -f "$STATE_FILE" ]]; then
            local LAST_ALERT_TIME
            LAST_ALERT_TIME=$(cat "$STATE_FILE")
            local CURRENT_TIME
            CURRENT_TIME=$(date +%s)
            local DIFF=$((CURRENT_TIME - LAST_ALERT_TIME))

            if (( DIFF > ALERT_MUTE_PERIOD )); then
                _send_telegram_raw "🔁 *Напоминание:* Проблема сохраняется!
$MSG_TEXT"
                echo "$CURRENT_TIME" > "$STATE_FILE"
                log_msg "REMINDER SENT: $ALERT_ID"
            else
                log_msg "MUTE: $ALERT_ID (Too soon to repeat)"
            fi
        else
            _send_telegram_raw "🔥 *Проблема обнаружена:*
$MSG_TEXT"
            date +%s > "$STATE_FILE"
            log_msg "NEW ALERT SENT: $ALERT_ID"
        fi

    elif [[ "$STATUS" == "OK" ]]; then
        if [[ -f "$STATE_FILE" ]]; then
            local HOST
            HOST=$(hostname)
            _send_telegram_raw "✅ *Восстановление (${HOST}):*
Проблема с *${ALERT_ID}* решена."
            rm -f "$STATE_FILE"
            log_msg "RECOVERY SENT: $ALERT_ID"
        fi
    fi
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_msg "ERROR: Command '$1' not found."
        exit 1
    fi
}
