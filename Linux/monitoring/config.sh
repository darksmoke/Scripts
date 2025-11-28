#!/bin/bash
# /opt/monitoring/config.sh
# v.1.2
#
# Глобальные настройки (ЗНАЧЕНИЯ ПО УМОЛЧАНИЮ).
# Этот файл ПЕРЕЗАПИСЫВАЕТСЯ при обновлении.
# Для своих настроек используйте файл config_local.sh

# --- Настройки Telegram ---
# (Оставьте пустыми здесь, если хотите задавать их только локально)
BOT_TOKEN=""
CHAT_ID=""

# --- Глобальные пути ---
INSTALL_DIR="/opt/monitoring"
LOG_FILE="/var/log/monitoring.log"
STATE_DIR="/tmp/monitoring_state"

# --- Пороги (Thresholds) - DEFAULTS ---
CPU_THRESHOLD=80
RAM_THRESHOLD=10
DISK_THRESHOLD=10
IOWAIT_THRESHOLD=10.0
SWAP_THRESHOLD=60
TEMP_WARNING=80
TEMP_CRITICAL=95
UPTIME_MIN_MINUTES=60
ALERT_MUTE_PERIOD=3600

# --- Исключения ---
DISK_EXCLUDE_TYPE="tmpfs|devtmpfs|squashfs|overlay"
DISK_EXCLUDE_PATH="/snap|/run"

# --- Настройки SMART ---
SMART_REALLOCATED_LIMIT=5
SMART_PENDING_LIMIT=0

# =================================================================
# ПОДКЛЮЧЕНИЕ ЛОКАЛЬНЫХ НАСТРОЕК (ПЕРЕОПРЕДЕЛЕНИЕ)
# =================================================================
# Если существует config_local.sh, берем настройки оттуда.
# Это позволяет обновлять config.sh без потери ваших паролей и порогов.
if [[ -f "${INSTALL_DIR}/config_local.sh" ]]; then
    source "${INSTALL_DIR}/config_local.sh"
fi
