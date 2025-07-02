#!/bin/bash
#
# Скрипт для установки и настройки системы мониторинга.
# v.1.0
#
set -euo pipefail

# === Конфигурация ===
INSTALL_DIR="${1:-/root/scripts/monitoring}"
RAW_BASE="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring"
# Список скриптов для скачивания (без файлов конфигурации)
SCRIPTS=(
    send_telegram.sh check_cpu.sh check_ram.sh check_disk.sh
    check_iowait.sh check_uptime.sh check_raid.sh check_temp.sh
    check_swap.sh check_smart.sh
)

# === Функции ===

install_packages() {
    echo "📦 Установка необходимых пакетов..."
    # Обновляем список пакетов только если это не делалось недавно
    if [ -z "$(find /var/lib/apt/lists -maxdepth 1 -mmin -60 -type f)" ]; then
        apt-get update -y
    fi
    apt-get install -y curl smartmontools lm-sensors mdadm bc sysstat
}

download_scripts() {
    echo "⬇️  Загрузка скриптов мониторинга в ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    for script in "${SCRIPTS[@]}"; do
        echo "   - ${script}"
        curl -fsSL "${RAW_BASE}/${script}" -o "${script}"
        chmod +x "${script}"
    done
}

create_config_files() {
    # --- Создание config.ini с настройками по умолчанию ---
    if [[ ! -f "${INSTALL_DIR}/config.ini" ]]; then
        echo "📝 Создание файла конфигурации config.ini..."
        cat <<'EOF' > "${INSTALL_DIR}/config.ini"
#
# Файл конфигурации для скриптов мониторинга (не секретные данные)
#

# --- Пороги для оповещений ---
CPU_THRESHOLD_PERCENT=80
DISK_FREE_SPACE_THRESHOLD=10
IO_WAIT_THRESHOLD=5.0
RAM_AVAILABLE_THRESHOLD_PERCENT=10
SWAP_USAGE_THRESHOLD_PERCENT=60
UPTIME_ALERT_THRESHOLD_MINUTES=60

# --- Пороги температуры ---
TEMP_THRESHOLD_WARNING=80
TEMP_THRESHOLD_CRITICAL=95

# --- Настройки проверки S.M.A.R.T. ---
SMART_REALLOCATED_SECTOR_CT=5
SMART_PENDING_SECTOR_CT=0
SMART_UNCORRECTABLE_SECTOR_CT=0
SMART_COMMAND_TIMEOUT=0

# --- Списки исключений ---
DISK_EXCLUDE_LIST="tmpfs devtmpfs squashfs"
EOF
    else
        echo "🔧 Файл config.ini уже существует, создание пропущено."
    fi

    # --- Создание secrets.ini для токенов ---
    if [[ ! -f "${INSTALL_DIR}/secrets.ini" ]]; then
        echo "🔑 Создание файла для секретных данных secrets.ini..."
        cat <<'EOF' > "${INSTALL_DIR}/secrets.ini"
#
# ВНИМАНИЕ! Этот файл содержит секретные данные.
# Укажите ваш токен и ID чата Telegram.
#
BOT_TOKEN=""
CHAT_ID=""
EOF
    else
        echo "🔑 Файл secrets.ini уже существует, создание пропущено."
    fi
}

setup_cron() {
    echo "🛠️  Настройка crontab..."
    local tmp_cron
    tmp_cron=$(mktemp)
    
    # Получаем текущие задачи и удаляем все, связанные с нашим мониторингом
    crontab -l 2>/dev/null | grep -v "${INSTALL_DIR}" > "$tmp_cron" || true

    # Добавляем блок заданий мониторинга
    echo "" >> "$tmp_cron"
    echo "# --- Блок заданий мониторинга (${INSTALL_DIR}) ---" >> "$tmp_cron"
    
    local cron_expr
    for script in "${SCRIPTS[@]}"; do
        [[ "$script" == "send_telegram.sh" ]] && continue
        
        # Назначаем разное время выполнения для разных скриптов
        case "$script" in
            check_smart.sh|check_raid.sh) cron_expr="10 * * * *" ;; # Раз в час
            check_uptime.sh) cron_expr="* * * * *" ;;               # Каждую минуту
            *) cron_expr="*/5 * * * *" ;;                           # Каждые 5 минут
        esac
        
        echo "${cron_expr} bash ${INSTALL_DIR}/${script}" >> "$tmp_cron"
    done
    echo "# --- Конец блока заданий мониторинга ---" >> "$tmp_cron"

    crontab "$tmp_cron"
    rm "$tmp_cron"
    echo "✅ Crontab успешно обновлён."
}

# === Основная логика ===
main() {
    install_packages
    download_scripts
    create_config_files
    setup_cron

    echo -e "\n🎉 Установка завершена!"
    echo -e "‼️ ВАЖНО: Отредактируйте файл \e[1;33m${INSTALL_DIR}/secrets.ini\e[0m и впишите ваши BOT_TOKEN и CHAT_ID."
    echo "Для обновления скриптов в будущем, создайте и используйте скрипт update.sh (см. документацию)."
}

main "$@"
