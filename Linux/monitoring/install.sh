#!/bin/bash
# /opt/monitoring/install.sh
# v.1.5
#
# Скрипт установки системы мониторинга.
# Реализует разделение настроек (config.sh + config_local.sh)
# и настройку Cron через /etc/cron.d/

set -euo pipefail

# === Конфигурация ===
INSTALL_DIR="/opt/monitoring"
REPO_URL="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring"

# Список всех файлов, которые нужно скачать/обновить из репозитория
SCRIPTS=(
    "config.sh"
    "utils.sh"
    "check_cpu.sh"
    "check_disk.sh"
    "check_qemu_agent.sh"
    "check_ram.sh"
    "check_smart.sh"
    "check_reboot.sh"
    "check_iowait.sh"
    "check_uptime.sh"
    "check_raid.sh"
    "check_temp.sh"
    "check_swap.sh"
    "update.sh"
    "config_local.example"
)

# === 1. Подготовка директории ===
echo "📂 Создание директории ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
chmod 750 "$INSTALL_DIR"

# === 2. Установка зависимостей ===
echo "📦 Установка системных пакетов..."
if [ -f /etc/debian_version ]; then
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y curl smartmontools lm-sensors mdadm bc sysstat jq >/dev/null 2>&1
elif [ -f /etc/redhat-release ]; then
    yum install -y curl smartmontools lm-sensors mdadm bc sysstat jq >/dev/null 2>&1
fi

# === 3. Скачивание скриптов ===
echo "⬇️ Скачивание файлов с GitHub..."

for file in "${SCRIPTS[@]}"; do
    echo "   - Обновление: ${file}"
    if curl -fsSL "${REPO_URL}/${file}" -o "${INSTALL_DIR}/${file}"; then
        chmod +x "${INSTALL_DIR}/${file}"
    else
        echo "❌ Ошибка скачивания ${file}. Проверьте URL или интернет."
        exit 1
    fi
done

# Снимаем флаг исполнения с библиотек (их не нужно запускать напрямую)
chmod -x "${INSTALL_DIR}/config.sh" "${INSTALL_DIR}/utils.sh"

# === 4. Создание локального конфига (если нет) ===
LOCAL_CONF="${INSTALL_DIR}/config_local.sh"

if [[ ! -f "$LOCAL_CONF" ]]; then
    echo "📝 Создание шаблона для локальных настроек (config_local.sh)..."
    cat <<EOF > "$LOCAL_CONF"
#!/bin/bash
# ==========================================
# ЛОКАЛЬНЫЕ НАСТРОЙКИ СЕРВЕРА: $(hostname)
# ==========================================
# Этот файл НЕ обновляется автоматически.
# Впишите сюда свои токены и индивидуальные пороги.

# --- Telegram (ОБЯЗАТЕЛЬНО) ---
BOT_TOKEN=""
CHAT_ID=""

# --- Переопределение порогов (Опционально) ---
# Раскомментируйте, если хотите изменить значение для этого сервера
# DISK_THRESHOLD=15           # % (Дефолт: 10)
# CPU_THRESHOLD=90            # % (Дефолт: 80)
# ALERT_MUTE_PERIOD=7200      # Сек (Дефолт: 3600 - 1 час)

EOF
    chmod 640 "$LOCAL_CONF"
    echo "⚠️ ВНИМАНИЕ: Создан файл ${LOCAL_CONF}. Впишите туда BOT_TOKEN!"
else
    echo "✅ Файл config_local.sh обнаружен. Ваши настройки сохранены."
fi

# === 5. Настройка Cron (System-wide) ===
echo "⏰ Настройка задач Cron (/etc/cron.d/monitoring)..."

cat <<EOF > /etc/cron.d/monitoring
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# 1. Автообновление скриптов (Раз в сутки в 04:00)
0 4 * * * root /opt/monitoring/update.sh >> /var/log/monitoring_update.log 2>&1

# 2. Частые проверки (Каждые 5 минут)
*/5 * * * * root /opt/monitoring/check_cpu.sh
*/5 * * * * root /opt/monitoring/check_ram.sh
*/5 * * * * root /opt/monitoring/check_disk.sh
*/5 * * * * root /opt/monitoring/check_iowait.sh
*/5 * * * * root /opt/monitoring/check_swap.sh
*/5 * * * * root /opt/monitoring/check_temp.sh

# 3. Редкие проверки (Раз в час)
# Разносим по времени, чтобы не грузить систему одновременно
15 * * * * root /opt/monitoring/check_smart.sh
20 * * * * root /opt/monitoring/check_raid.sh
*/10 * * * * root /opt/monitoring/check_uptime.sh
# Проверка QEMU агента в виртуалках (раз в сутки в 09:00 утра)
0 9 * * * root /opt/monitoring/check_qemu_agent.sh
EOF

# Права на cron-файл (обязательно 644)
chmod 644 /etc/cron.d/monitoring

# === 6. Финиш ===
echo "🎉 Установка завершена!"
echo "---------------------------------------------------"
if [[ -z "$(grep 'BOT_TOKEN=""' "$LOCAL_CONF")" ]]; then
     echo "ℹ️  Текущий конфиг активен."
else
     echo "‼️  ВАЖНО: Отредактируйте файл настроек:"
     echo "   nano ${LOCAL_CONF}"
fi
echo "---------------------------------------------------"
