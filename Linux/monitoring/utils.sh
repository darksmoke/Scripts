#!/bin/bash
# /opt/monitoring/utils.sh
# v.1.6 - Telegram delivery check, token off the command line, LC_ALL=C

# Вывод free/df/virsh/sensors локализуется: на сервере с ru_RU `free` пишет
# "Подкачка:" вместо "Swap:", и парсинг молча ломается. Тексты алертов — это
# строки самих скриптов, на них C-локаль не влияет.
export LC_ALL=C

source "$(dirname "$0")/config.sh"

mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"

# Однократный перенос активных алертов из старого /tmp/monitoring_state, чтобы
# после обновления они не пришли повторно как новые. Переносим только если
# каталог настоящий (не симлинк) и принадлежит root, и только обычные файлы.
OLD_STATE_DIR="/tmp/monitoring_state"
if [[ "$STATE_DIR" != "$OLD_STATE_DIR" && -d "$OLD_STATE_DIR" && ! -L "$OLD_STATE_DIR" \
      && "$(stat -c %u "$OLD_STATE_DIR" 2>/dev/null)" == "0" ]]; then
    find "$OLD_STATE_DIR" -maxdepth 1 -type f -name '*.lock' -user root \
        -exec mv -n -t "$STATE_DIR" {} + 2>/dev/null
    rm -rf "$OLD_STATE_DIR"
fi

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Один запрос к Bot API. Печатает ответ Telegram.
# URL с токеном передаётся curl через конфиг на stdin (-K -), а не аргументом:
# аргументы процесса видны любому локальному пользователю в `ps`.
# --data-urlencode, а не -d: иначе "&", "+", "%" в тексте алерта рвут/портят
# сообщение.
_telegram_request() {
    local message="$1"
    local parse_mode="$2"
    local args=(--data-urlencode "chat_id=${CHAT_ID}" --data-urlencode "text=${message}")
    [[ -n "$parse_mode" ]] && args+=(--data-urlencode "parse_mode=${parse_mode}")
    printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$BOT_TOKEN" \
        | curl -sS --max-time 10 -K - "${args[@]}" 2>&1
}

# Возвращает 0 только если Telegram подтвердил доставку ("ok":true).
_send_telegram_raw() {
    local message="$1"
    if [[ -z "${BOT_TOKEN:-}" || -z "${CHAT_ID:-}" ]]; then
        log_msg "ERROR: Telegram credentials missing."
        return 1
    fi

    # Скрипты собирают отчёты через REPORT+="...\n" — в bash это буквальные
    # два символа "\n", и Telegram показывал их как есть ("мин:\n\n15 19:22"),
    # а после ``` съедал первое слово как "язык" блока кода.
    message="${message//\\n/$'\n'}"

    local resp
    resp=$(_telegram_request "$message" "Markdown")
    if echo "$resp" | grep -q '"ok":true'; then
        return 0
    fi

    # Markdown ломается на непарном "_" или "*" из данных (имя ВМ, текст
    # ошибки, строка журнала) — Telegram отвечает "can't parse entities" и
    # сообщение не доставляется. Повторяем тем же текстом без разметки:
    # некрасиво, но алерт дойдёт.
    if echo "$resp" | grep -q "can't parse entities"; then
        resp=$(_telegram_request "$message" "")
        if echo "$resp" | grep -q '"ok":true'; then
            log_msg "WARN: Markdown rejected by Telegram, sent as plain text."
            return 0
        fi
    fi

    log_msg "ERROR: Telegram send failed: $(echo "$resp" | tr -d '\n' | cut -c1-300)"
    return 1
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

# Lock-файл создаётся/обновляется/удаляется только после подтверждённой
# доставки: если Telegram недоступен или отклонил сообщение, следующий запуск
# попробует снова, а не посчитает алерт отправленным.
manage_alert() {
    local ALERT_ID="$1"
    local STATUS="$2"
    local MSG_TEXT="$3"
    # 4-й необязательный параметр: "1" — не глушить алерт в глобальное окно
    # обслуживания. Для критичных аппаратных сигналов (например, зависание
    # контроллера диска), которые нельзя откладывать до утра.
    local BYPASS_MAINTENANCE="${4:-0}"
    local STATE_FILE="${STATE_DIR}/${ALERT_ID}.lock"

    if [[ "$STATUS" == "ERROR" ]]; then

        # === ПРОВЕРКА ГЛОБАЛЬНОГО МЕЙТЕНАНСА ===
        if [[ "$BYPASS_MAINTENANCE" != "1" ]] && is_maintenance_now; then
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
                if _send_telegram_raw "🔁 *Напоминание:* Проблема сохраняется!
$MSG_TEXT"; then
                    echo "$CURRENT_TIME" > "$STATE_FILE"
                    log_msg "REMINDER SENT: $ALERT_ID"
                fi
            else
                log_msg "MUTE: $ALERT_ID (Too soon to repeat)"
            fi
        else
            if _send_telegram_raw "🔥 *Проблема обнаружена:*
$MSG_TEXT"; then
                date +%s > "$STATE_FILE"
                log_msg "NEW ALERT SENT: $ALERT_ID"
            fi
        fi

    elif [[ "$STATUS" == "OK" ]]; then
        if [[ -f "$STATE_FILE" ]]; then
            local HOST
            HOST=$(hostname)
            if _send_telegram_raw "✅ *Восстановление (${HOST}):*
Проблема \`${ALERT_ID}\` решена."; then
                rm -f "$STATE_FILE"
                log_msg "RECOVERY SENT: $ALERT_ID"
            fi
        fi
    fi
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_msg "ERROR: Command '$1' not found."
        exit 1
    fi
}
