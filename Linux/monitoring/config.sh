#!/bin/bash
# /opt/monitoring/config.sh
# v.1.3
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
# Не в /tmp: root пишет/удаляет здесь lock-файлы, а предсказуемый путь в
# общедоступном /tmp позволяет локальному пользователю подложить симлинки.
STATE_DIR="/var/lib/monitoring/state"

# --- Пороги (Thresholds) - DEFAULTS ---
CPU_THRESHOLD=80
RAM_THRESHOLD=10
DISK_THRESHOLD=10
IOWAIT_THRESHOLD=25.0
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
# Порог износа SSD/NVMe, % израсходованного ресурса (NVMe "Percentage Used",
# у SATA SSD — 100 минус нормализованное значение wear-атрибута)
SMART_WEAR_LIMIT=90
# Исключить устройства из SMART-проверки (regex по "устройство тип модель серийник"),
# например виртуальный том HW-RAID, у которого SMART нет: "^/dev/sda scsi"
SMART_EXCLUDE_REGEX=""
# Глубина поиска в журнале (минуты) следов зависания/сброса контроллера диска.
# Должна перекрывать интервал запуска check_smart.sh (по умолчанию раз в 5
# часов = 300 мин) с запасом, иначе часть инцидентов между запусками будет
# пропущена.
SMART_LOOKBACK_MIN=315

# --- Maintenance Window для IO Wait ---
# Час начала и час окончания игнорирования (0-23).
# Например: с 2 ночи до 6 утра.
# Если оставить пустым - проверка работает круглосуточно.
IOWAIT_MNT_START=23
IOWAIT_MNT_END=8

# =================================================================
# ПОДКЛЮЧЕНИЕ ЛОКАЛЬНЫХ НАСТРОЕК (ПЕРЕОПРЕДЕЛЕНИЕ)
# =================================================================
# Если существует config_local.sh, берем настройки оттуда.
# Это позволяет обновлять config.sh без потери ваших паролей и порогов.
if [[ -f "${INSTALL_DIR}/config_local.sh" ]]; then
    source "${INSTALL_DIR}/config_local.sh"
fi

