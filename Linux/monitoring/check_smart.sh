#!/bin/bash
# /opt/monitoring/check_smart.sh
# v.1.5 - Universal SMART checks for HDD / SATA-SSD / NVMe + controller-hang detection
#
# ВАЖНО: у NVMe нет классической ATA-таблицы атрибутов (ID 5/197), а общий
# health-флаг smartctl -H остаётся PASSED даже когда контроллер диска реально
# виснет (I/O timeout -> reset controller -> Device not ready). Поэтому для
# NVMe читаем его собственные поля SMART/Health лога (Critical Warning,
# Media and Data Integrity Errors, Percentage Used), а зависание контроллера
# ловим отдельно — по следам в ядерном логе, т.к. SMART его не показывает.
set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

check_dependency "smartctl"
check_dependency "lsblk"

HOST=$(hostname)
REPORT=""
HAS_ERROR=0
HANG_REPORT=""
HAS_HANG=0

SMART_LOOKBACK_MIN="${SMART_LOOKBACK_MIN:-65}"
SMART_NVME_PCT_USED_LIMIT="${SMART_NVME_PCT_USED_LIMIT:-90}"

get_attr() {
    echo "$1" | awk -v id="$2" '$1 == id {print $10; exit}' | sed 's/^0*//' | awk '{if($1=="") print 0; else print $1}'
}

# Достаёт значение поля из вывода `smartctl -A` для NVMe (формат "Key:   value",
# без номеров атрибутов как у ATA).
get_nvme_field() {
    echo "$1" | grep -m1 "^$2:" | sed -E "s/^$2:[[:space:]]*//"
}

# ИЗМЕНЕНИЕ: Добавили колонку RM (Removable) в вывод lsblk.
# awk проверяет: если колонка 2 (RM) равна 0 И колонка 3 (TYPE) равна disk -> печатаем имя.
DISKS=$(lsblk -d -n -o NAME,RM,TYPE | awk '$2 == 0 && $3 == "disk" {print "/dev/"$1}')

for disk in $DISKS; do
    DISK_ISSUES=""
    DISK_NAME=$(basename "$disk")
    IS_NVME=0
    [[ "$disk" == /dev/nvme* ]] && IS_NVME=1

    # Пытаемся получить статус здоровья
    # Добавили тайм-аут, чтобы не висело на битых дисках
    HEALTH_OUTPUT=$(timeout 10 smartctl -H "$disk" 2>&1)

    # Парсим результат
    HEALTH=$(echo "$HEALTH_OUTPUT" | grep -i "result" | awk -F: '{print $2}' | xargs) || HEALTH="UNKNOWN"

    # Если smartctl вернул ошибку выполнения (например, диск не поддерживает SMART),
    # но при этом не сказал явно FAILED, то помечаем как WARN, а не CRIT, или пропускаем.

    if [[ -z "$HEALTH" ]]; then
        # Если статус пустой, значит smartctl не смог прочитать данные
        # Это проблема, но возможно диск просто не поддерживает SMART (старые RAID контроллеры и т.д.)
        DISK_ISSUES+=" SMART Status not available (Check manually)\n"
    elif [[ "$HEALTH" != "PASSED" && "$HEALTH" != "OK" ]]; then
        DISK_ISSUES+="🔴 Health Check Failed: ${HEALTH}\n"
    elif [[ "$IS_NVME" -eq 1 ]]; then
        # NVMe: проверяем собственные поля, а не ATA-атрибуты (для них тут
        # никогда не совпадёт ни один ID, и HDD/SATA-логика молча даст 0).
        ATTRS=$(timeout 10 smartctl -A "$disk" 2>/dev/null) || true

        CRIT=$(get_nvme_field "$ATTRS" "Critical Warning")
        if [[ -n "$CRIT" && "$CRIT" != "0x00" ]]; then
            DISK_ISSUES+="🔴 Critical Warning: ${CRIT} (норма 0x00)\n"
        fi

        MEDIA_ERR=$(get_nvme_field "$ATTRS" "Media and Data Integrity Errors")
        if [[ "$MEDIA_ERR" =~ ^[0-9]+$ ]] && (( MEDIA_ERR > 0 )); then
            DISK_ISSUES+="🔴 Media and Data Integrity Errors: ${MEDIA_ERR}\n"
        fi

        PCT_USED=$(get_nvme_field "$ATTRS" "Percentage Used" | tr -dc '0-9')
        if [[ -n "$PCT_USED" ]] && (( PCT_USED >= SMART_NVME_PCT_USED_LIMIT )); then
            DISK_ISSUES+=" Percentage Used: ${PCT_USED}% (Порог: ${SMART_NVME_PCT_USED_LIMIT}%)\n"
        fi
    else
        # Классические атрибуты ATA/SATA (актуально для HDD и SATA SSD)
        ATTRS=$(timeout 10 smartctl -A "$disk" 2>/dev/null) || true

        RSC=$(get_attr "$ATTRS" 5)
        if (( RSC > SMART_REALLOCATED_LIMIT )); then
            DISK_ISSUES+=" Reallocated Sectors (ID 5): ${RSC}\n"
        fi

        PSC=$(get_attr "$ATTRS" 197)
        if (( PSC > SMART_PENDING_LIMIT )); then
            DISK_ISSUES+=" Pending Sectors (ID 197): ${PSC}\n"
        fi
    fi

    if [[ -n "$DISK_ISSUES" ]]; then
        REPORT+=" *Disk ${disk}*:\n${DISK_ISSUES}\n"
        HAS_ERROR=1
    fi

    # === Детект зависания/сброса контроллера за последние N минут ===
    # SMART тут бессилен: health остаётся PASSED, пока диск не завис "насмерть".
    # Ищем прямые следы в журнале ядра — отдельный паттерн для NVMe и для ATA/SATA.
    if [[ "$IS_NVME" -eq 1 ]]; then
        PATTERN="nvme.*(timeout|reset controller|Device not ready)"
    else
        # Примечание: ядро логирует ошибки ATA-порта по имени вида "ata1.00",
        # а не по /dev/sdX, поэтому точное сопоставление с конкретным диском
        # ненадёжно — паттерн общий по всей ATA-подсистеме хоста.
        PATTERN="ata[0-9]+.*(exception Emask|hard resetting link|failed command)|blk_update_request:.*I/O error.*dev ${DISK_NAME}"
    fi

    RECENT_HANG=$(journalctl -k --since "-${SMART_LOOKBACK_MIN} min" --no-pager 2>/dev/null | grep -iE "$PATTERN" | tail -5)
    if [[ -n "$RECENT_HANG" ]]; then
        HANG_REPORT+=" *${disk}* — признаки зависания/сброса за последние ${SMART_LOOKBACK_MIN} мин:\n\`\`\`\n${RECENT_HANG}\n\`\`\`\n"
        HAS_HANG=1
    fi
done

ALERT_ID="smart_health"

if [[ "$HAS_ERROR" -eq 1 ]]; then
    MSG=$(cat <<EOF
🔧 *SMART Ошибки: ${HOST}*
${REPORT}
EOF
)
    manage_alert "$ALERT_ID" "ERROR" "$MSG"
else
    manage_alert "$ALERT_ID" "OK" ""
fi

# Алерт по зависанию контроллера НЕ подчиняется глобальному окну обслуживания
# (4-й аргумент "1" у manage_alert) — диск, который реально виснет посреди
# ночи, это не шум, который можно спокойно отложить до утра.
if [[ "$HAS_HANG" -eq 1 ]]; then
    MSG=$(cat <<EOF
🆘 *Диск завис/сбросился: ${HOST}*
${HANG_REPORT}
EOF
)
    manage_alert "disk_controller_hang" "ERROR" "$MSG" "1"
else
    manage_alert "disk_controller_hang" "OK" ""
fi

exit 0
