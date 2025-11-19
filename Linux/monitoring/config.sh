#!/bin/bash
# /opt/monitoring/config.sh

# --- Настройки Telegram (СЕКРЕТНЫЕ ДАННЫЕ) ---
# В реальном проде лучше вынести в secrets.sh и добавить в .gitignore
BOT_TOKEN="ВАШ_ТОКЕН"
CHAT_ID="ВАШ_CHAT_ID"

# --- Глобальные пути ---
INSTALL_DIR="/opt/monitoring"
LOG_FILE="/var/log/monitoring.log"

# --- Пороги (Thresholds) ---
CPU_THRESHOLD=80              # %
RAM_THRESHOLD=10              # % (Если свободно меньше X%)
DISK_THRESHOLD=10             # % (Если свободно меньше X%)
IOWAIT_THRESHOLD=10.0         # %
SWAP_THRESHOLD=60             # %
TEMP_WARNING=80               # °C
TEMP_CRITICAL=95              # °C
UPTIME_MIN_MINUTES=60         # Минуты

# --- Исключения ---
# Файловые системы для игнорирования (через pipe | для grep)
DISK_EXCLUDE_TYPE="tmpfs|devtmpfs|squashfs|overlay"
DISK_EXCLUDE_PATH="/snap|/run"

# --- Настройки SMART ---
SMART_REALLOCATED_LIMIT=5
SMART_PENDING_LIMIT=0