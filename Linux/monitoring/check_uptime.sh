#!/bin/bash
#
# Скрипт для проверки времени работы системы (uptime) и отправки
# уведомления в случае недавней перезагрузки.
# v.1.1
#

# Строгий режим: выход при ошибке, при использовании необъявленной переменной
set -euo pipefail

# --- Инициализация ---

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

source "${SCRIPT_DIR}/config.ini"
source "${SCRIPT_DIR}/secrets.ini"

# Загружаем библиотеку отправки
source "${SCRIPT_DIR}/send_telegram.sh"

# --- Основная логика ---

echo "Начало проверки времени работы системы..."

# Получаем время работы системы в минутах
UPTIME_MINUTES=$(awk '{print int($1/60)}' /proc/uptime)

echo "  - Время работы: ${UPTIME_MINUTES} мин."
echo "  - Порог для оповещения: ${UPTIME_ALERT_THRESHOLD_MINUTES} мин."

# Сравниваем время работы с порогом из файла конфигурации
if (( UPTIME_MINUTES < UPTIME_ALERT_THRESHOLD_MINUTES )); then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')

  MSG=$(cat <<EOF
🔄 *Обнаружена недавняя перезагрузка сервера: ${HOST}* 🔄

🕒 *Время проверки:* ${TIME}
⏱️ *Время работы (Uptime):* ${UPTIME_MINUTES} мин.

Сервер был перезагружен менее ${UPTIME_ALERT_THRESHOLD_MINUTES} минут назад.
EOF
)

  echo "!!! ОБНАРУЖЕНА НЕДАВНЯЯ ПЕРЕЗАГРУЗКА! Отправка уведомления в Telegram..."
  send_telegram "$MSG"
  echo "Уведомление отправлено."
else
  echo "Время работы системы в норме."
fi

exit 0
