#!/bin/bash
# /opt/monitoring/install.sh
set -euo pipefail

INSTALL_DIR="/opt/monitoring"
REPO_URL="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring"
SCRIPTS=("config.sh" "utils.sh" "check_cpu.sh" "check_disk.sh" "check_ram.sh" "check_smart.sh" "update.sh")

# 1. Подготовка директории
echo "📂 Создание директории ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
chmod 750 "$INSTALL_DIR"

# 2. Установка зависимостей
echo "📦 Установка пакетов..."
if [ -f /etc/debian_version ]; then
    apt-get update -qq && apt-get install -y curl smartmontools lm-sensors mdadm bc sysstat jq > /dev/null
elif [ -f /etc/redhat-release ]; then
    yum install -y curl smartmontools lm-sensors mdadm bc sysstat jq > /dev/null
fi

# 3. Скачивание скриптов (ВНИМАНИЕ: тут нужна логика скачивания или копирования)
# Если скрипт запускается из git-репозитория локально:
cp ./*.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh
# Убираем +x с конфигов
chmod -x "$INSTALL_DIR/config.sh" "$INSTALL_DIR/utils.sh"

# 4. Настройка Cron (SYSTEM WIDE)
echo "⏰ Настройка Cron через /etc/cron.d/monitoring..."

# Создаем файл задания. Указываем пользователя root явно.
cat <<EOF > /etc/cron.d/monitoring
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Обновление скриптов (раз в сутки в 04:00)
0 4 * * * root $INSTALL_DIR/update.sh >> /var/log/monitoring_update.log 2>&1

# Проверки (каждые 5 минут)
*/5 * * * * root $INSTALL_DIR/check_cpu.sh
*/5 * * * * root $INSTALL_DIR/check_ram.sh
*/5 * * * * root $INSTALL_DIR/check_disk.sh
*/5 * * * * root $INSTALL_DIR/check_iowait.sh

# Редкие проверки (раз в час)
15 * * * * root $INSTALL_DIR/check_smart.sh
20 * * * * root $INSTALL_DIR/check_raid.sh
EOF

chmod 644 /etc/cron.d/monitoring
echo "✅ Установка завершена. Конфиг: ${INSTALL_DIR}/config.sh"
