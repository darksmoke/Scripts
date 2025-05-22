#!/bin/bash

# ==== Настройки ====
REPO_URL="https://github.com/your-user/monitoring-scripts.git"  # 🔁 ЗАМЕНИ на свой URL
INSTALL_DIR="${1:-/root/scripts/monitoring}"                    # путь по умолчанию или из аргумента
BRANCH="main"  # или укажи ветку, если надо

echo "📁 Установка в: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# ==== Установка зависимостей ====
echo "📦 Установка зависимостей..."
apt update -y && apt install -y curl wget git smartmontools lm-sensors util-linux grep gawk mdadm

# ==== Клонирование репозитория ====
echo "📥 Клонируем репозиторий..."
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "🔄 Обновляем существующий репозиторий..."
  git -C "$INSTALL_DIR" pull
else
  git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

# ==== Проверка config.ini ====
if [[ ! -f "$INSTALL_DIR/config.ini" ]]; then
  echo "⚠️ ВНИМАНИЕ: файл config.ini не найден в $INSTALL_DIR"
  echo "Создайте его вручную с параметрами:"
  echo "TOKEN=..."
  echo "CHAT_ID=..."
  exit 1
fi

# ==== Регистрация crontab ====
echo "🕒 Настраиваем CRON..."

CRON_CONTENT=$(cat <<EOF
*/5 * * * * bash $INSTALL_DIR/check_disk.sh
*/5 * * * * bash $INSTALL_DIR/check_ram.sh
*/5 * * * * bash $INSTALL_DIR/check_cpu.sh
*/5 * * * * bash $INSTALL_DIR/check_iowait.sh
*/5 * * * * bash $INSTALL_DIR/check_uptime.sh
*/10 * * * * bash $INSTALL_DIR/check_raid.sh
*/5 * * * * bash $INSTALL_DIR/check_temp.sh
*/5 * * * * bash $INSTALL_DIR/check_swap.sh
*/60 * * * * bash $INSTALL_DIR/check_smart.sh
EOF
)


for SCRIPT in check_disk.sh check_ram.sh check_cpu.sh check_iowait.sh check_uptime.sh check_raid.sh check_temp.sh check_swap.sh check_smart.sh; do
  SCRIPT_PATH="$INSTALL_DIR/$SCRIPT"
  case $SCRIPT in
    check_smart.sh)     INTERVAL="60 * * * *" ;;
    check_raid.sh)      INTERVAL="*/10 * * * *" ;;
    *)                  INTERVAL="*/5 * * * *" ;;
  esac
  CRON_LINE="$INTERVAL bash $SCRIPT_PATH"
  crontab -l 2>/dev/null | grep -F "$SCRIPT_PATH" >/dev/null || (
    echo "$CRON_LINE" >> /tmp/new_cron
  )
done

# Обновляем crontab, если есть новые строки
if [[ -f /tmp/new_cron ]]; then
  (crontab -l 2>/dev/null; cat /tmp/new_cron) | crontab -
  rm /tmp/new_cron
  echo "✅ Добавлены новые cron-задачи."
else
  echo "✔️ Cron уже настроен. Новых записей не требуется."
fi


echo "✅ Установка завершена."
