#!/bin/bash
#
# Библиотека для отправки сообщений в Telegram.
# Подключается через 'source'. Не запускается напрямую.
# v.1.0
#

send_telegram() {
  # Переменные делаем локальными, чтобы не засорять окружение
  local message_text="$1"

  # Проверяем, что необходимые переменные были загружены из config.ini
  if [[ -z "${BOT_TOKEN:-}" || -z "${CHAT_ID:-}" ]]; then
    echo "КРИТИЧЕСКАЯ ОШИБКА: BOT_TOKEN или CHAT_ID не определены. Проверьте config.ini." >&2
    return 1
  fi

  # Используем curl с таймаутом и показом ошибок (-sS)
  curl -sS --max-time 15 \
    -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${message_text}" \
    -d parse_mode="Markdown" > /dev/null # Ответ от Telegram нам не важен, если не было ошибки
}
