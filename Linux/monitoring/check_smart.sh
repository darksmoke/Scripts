#!/bin/bash
# /opt/monitoring/check_smart.sh
# v.1.6 - Universal SMART checks: HDD / SATA-SSD / SAS / NVMe / HW-RAID / USB-мосты
#
# Что проверяется:
#   * Все типы: код возврата smartctl (биты "DISK FAILING" и "pre-fail атрибут
#     ниже порога") — универсальный признак умирающего диска, не зависящий от
#     вендорских атрибутов. Плюс "smartctl не ответил" — сам по себе симптом.
#   * HDD/SATA-SSD (ATA): 5 Reallocated, 197 Pending, 198 Offline_Uncorrectable,
#     рост 187 Reported_Uncorrect и 199 UDMA_CRC (кабель/бэкплейн),
#     10 Spin_Retry (только HDD), износ SSD по нормализованному значению
#     вендорского wear-атрибута.
#   * NVMe: Critical Warning, Media Errors, Percentage Used.
#   * SAS/SCSI: grown defect list, рост неисправленных ошибок чтения/записи.
#   * Зависание/сброс контроллера — по журналу ядра, ПО КОНКРЕТНОМУ устройству
#     (ATA-порт, [sdX], nvmeN), включая предыдущую загрузку: если диск завис и
#     сервер перезагрузили, следы не теряются.
#
# Устройства берутся из `smartctl --scan-open` (видит диски за megaraid/cciss,
# USB-SAT мосты, правильный -d тип; не видит zram/virtio, у которых SMART нет).
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

SMART_LOOKBACK_MIN="${SMART_LOOKBACK_MIN:-315}"
SMART_REALLOCATED_LIMIT="${SMART_REALLOCATED_LIMIT:-5}"
SMART_PENDING_LIMIT="${SMART_PENDING_LIMIT:-0}"
# SMART_NVME_PCT_USED_LIMIT — старое имя, оставлено для совместимости с config_local.sh
SMART_WEAR_LIMIT="${SMART_NVME_PCT_USED_LIMIT:-${SMART_WEAR_LIMIT:-90}}"
SMART_EXCLUDE_REGEX="${SMART_EXCLUDE_REGEX:-}"
SMART_CMD_TIMEOUT="${SMART_CMD_TIMEOUT:-30}"
# Базовые значения счётчиков для детекта роста. Не в /tmp: должны переживать
# перезагрузку (рост ошибок прямо перед ребутом — самый интересный случай).
SMART_STATE_DIR="${SMART_STATE_DIR:-/var/lib/monitoring/smart}"
mkdir -p "$SMART_STATE_DIR" && chmod 700 "$SMART_STATE_DIR"

# Сырое значение ATA-атрибута (колонка RAW_VALUE, первое число)
get_attr() {
    echo "$1" | awk -v id="$2" '$1 == id {print $10; exit}' | sed 's/^0*//' | awk '{if($1=="") print 0; else print $1}'
}

# Нормализованное значение ATA-атрибута (колонка VALUE)
get_attr_value() {
    echo "$1" | awk -v id="$2" '$1 == id {print $4+0; exit}'
}

has_attr() {
    echo "$1" | awk -v id="$2" '$1 == id {f=1} END {exit !f}'
}

# Значение поля вида "Key:   value" (NVMe/SAS/информационная секция)
get_field() {
    echo "$1" | grep -m1 "^$2:" | sed -E "s/^$2:[[:space:]]*//"
}

# Детект роста счётчика относительно прошлого запуска.
# Печатает прошлое значение и возвращает 0, если счётчик вырос.
check_growth() {
    local key cur="$2" prev=""
    key=$(printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_')
    local f="${SMART_STATE_DIR}/${key}"
    [[ "$cur" =~ ^[0-9]+$ ]] || return 1
    [[ -f "$f" ]] && prev=$(<"$f")
    echo "$cur" > "$f"
    if [[ "$prev" =~ ^[0-9]+$ ]] && (( cur > prev )); then
        echo "$prev"
        return 0
    fi
    return 1
}

# === Список устройств ===
# Формат строк: "<device>|<smartctl -d type>"
DEVICES=()
while read -r dev _ dtype _; do
    [[ -z "$dev" || "$dev" == \#* ]] && continue
    DEVICES+=("${dev}|${dtype}")
done < <(timeout 60 smartctl --scan-open 2>/dev/null)

# Старые smartctl (до 7.x) могут не показывать NVMe в --scan-open, хотя
# SATA-диски показывают — тогда NVMe молча выпал бы из проверки.
for ctrl in /sys/class/nvme/nvme*; do
    [[ -e "$ctrl" ]] || continue
    name=$(basename "$ctrl")
    printf '%s\n' "${DEVICES[@]:-}" | grep -qE "^/dev/${name}(n[0-9]+)?\|" || DEVICES+=("/dev/${name}|nvme")
done

# Фолбэк для старых smartctl без --scan-open: невыемные блочные диски,
# кроме виртуальных/программных, у которых SMART не бывает.
if [[ ${#DEVICES[@]} -eq 0 ]]; then
    while read -r name; do
        DEVICES+=("/dev/${name}|auto")
    done < <(lsblk -d -n -o NAME,RM,TYPE | awk '$2 == 0 && $3 == "disk" && $1 !~ /^(zram|vd|xvd|nbd|rbd|loop)/ {print $1}')
fi

# Журнал ядра читаем один раз на все диски. _TRANSPORT=kernel вместо -k:
# -k ограничивается текущей загрузкой и теряет следы зависания, из-за которого
# сервер как раз и перезагрузили.
KLOG=$(journalctl _TRANSPORT=kernel --since "-${SMART_LOOKBACK_MIN} min" --no-pager -q 2>/dev/null)

for entry in "${DEVICES[@]}"; do
    disk="${entry%%|*}"
    dtype="${entry#*|}"
    KDEV=$(basename "$disk")
    DISK_ISSUES=""

    # Флешки/картридеры не мониторим
    if [[ -f "/sys/block/${KDEV}/removable" && "$(cat "/sys/block/${KDEV}/removable")" == "1" ]]; then
        continue
    fi

    OUT=$(timeout "$SMART_CMD_TIMEOUT" smartctl -H -i -A -n standby,0 -d "$dtype" "$disk" 2>&1)
    RC=$?

    MODEL=$(get_field "$OUT" "Device Model")
    [[ -z "$MODEL" ]] && MODEL=$(get_field "$OUT" "Model Number")
    [[ -z "$MODEL" ]] && MODEL=$(get_field "$OUT" "Product")
    SERIAL=$(get_field "$OUT" "Serial Number")
    [[ -z "$SERIAL" ]] && SERIAL=$(get_field "$OUT" "Serial number")
    # Ключ для счётчиков: серийник (не меняется при переименовании sda<->sdb)
    KEY="${SERIAL:-${disk}_${dtype}}"
    LABEL="${disk}"
    [[ "$dtype" != "auto" && "$disk" != /dev/nvme* && "$disk" != /dev/sd* ]] && LABEL+=" [${dtype}]"

    if [[ -n "$SMART_EXCLUDE_REGEX" ]] && echo "${disk} ${dtype} ${MODEL} ${SERIAL}" | grep -qE "$SMART_EXCLUDE_REGEX"; then
        continue
    fi

    if (( RC == 124 )); then
        # smartctl не ответил — диск/контроллер, скорее всего, висит
        HANG_REPORT+=" *${LABEL}* — smartctl не ответил за ${SMART_CMD_TIMEOUT} с\n"
        HAS_HANG=1
        continue
    fi

    if echo "$OUT" | grep -q "Device is in STANDBY mode"; then
        log_msg "SMART: ${disk} в standby, проверка пропущена"
        continue
    fi

    IS_NVME=0; IS_SCSI=0; IS_SSD=0
    if [[ "$dtype" == nvme* || "$disk" == /dev/nvme* ]] || echo "$OUT" | grep -q "^NVMe Version:"; then
        IS_NVME=1; IS_SSD=1
    elif echo "$OUT" | grep -qE "^(Transport protocol:|SMART Health Status:)"; then
        IS_SCSI=1
    fi
    echo "$OUT" | grep -qE "^Rotation Rate:[[:space:]]+Solid State" && IS_SSD=1

    # Биты кода возврата smartctl (man smartctl, EXIT STATUS):
    #   1 — не удалось открыть устройство / SMART недоступен
    #   3 — SMART status: DISK FAILING
    #   4 — pre-fail атрибут сейчас ниже порога
    # Бит 2 (часть команд не прошла) не алертим: напр. "invalid SMART checksum"
    # у части WD при полностью исправном диске. Биты 5-7 — история, вечный шум.
    if (( RC & 2 )); then
        DISK_ISSUES+="⚠️ SMART недоступен (проверьте вручную: smartctl -a -d ${dtype} ${disk})\n"
    fi
    if (( RC & 8 )); then
        DISK_ISSUES+="🔴 SMART: DISK FAILING\n"
    fi
    if (( RC & 16 )); then
        FAILING=$(echo "$OUT" | awk '$9 == "FAILING_NOW" {printf "%s ", $2}')
        DISK_ISSUES+="🔴 Pre-fail атрибуты ниже порога: \`${FAILING:-см. smartctl -A}\`\n"
    fi

    if (( RC & 2 )); then
        :
    elif [[ "$IS_NVME" -eq 1 ]]; then
        CRIT=$(get_field "$OUT" "Critical Warning")
        if [[ -n "$CRIT" && "$CRIT" != "0x00" ]]; then
            DISK_ISSUES+="🔴 Critical Warning: ${CRIT} (норма 0x00)\n"
        fi

        MEDIA_ERR=$(get_field "$OUT" "Media and Data Integrity Errors" | tr -dc '0-9')
        if [[ -n "$MEDIA_ERR" ]] && (( MEDIA_ERR > 0 )); then
            DISK_ISSUES+="🔴 Media and Data Integrity Errors: ${MEDIA_ERR}\n"
        fi

        PCT_USED=$(get_field "$OUT" "Percentage Used" | tr -dc '0-9')
        if [[ -n "$PCT_USED" ]] && (( PCT_USED >= SMART_WEAR_LIMIT )); then
            DISK_ISSUES+="⚠️ Износ: ${PCT_USED}% (Порог: ${SMART_WEAR_LIMIT}%)\n"
        fi
    elif [[ "$IS_SCSI" -eq 1 ]]; then
        GROWN=$(get_field "$OUT" "Elements in grown defect list" | tr -dc '0-9')
        if [[ -n "$GROWN" ]]; then
            if (( GROWN > SMART_REALLOCATED_LIMIT )); then
                DISK_ISSUES+="⚠️ Grown defect list: ${GROWN} (Порог: ${SMART_REALLOCATED_LIMIT})\n"
            elif PREV=$(check_growth "${KEY}_grown" "$GROWN"); then
                DISK_ISSUES+="⚠️ Grown defect list вырос: ${PREV} → ${GROWN}\n"
            fi
        fi

        # Error counter log: последняя колонка — "Total uncorrected errors"
        ERRLOG=$(timeout "$SMART_CMD_TIMEOUT" smartctl -l error -d "$dtype" "$disk" 2>/dev/null)
        for op in read write verify; do
            UNC=$(echo "$ERRLOG" | awk -v op="${op}:" '$1 == op {print $NF; exit}' | tr -dc '0-9')
            if [[ -n "$UNC" ]] && PREV=$(check_growth "${KEY}_unc_${op}" "$UNC"); then
                DISK_ISSUES+="🔴 Неисправленные ошибки (${op}) выросли: ${PREV} → ${UNC}\n"
            fi
        done
    else
        # ATA/SATA: HDD и SATA SSD
        RSC=$(get_attr "$OUT" 5)
        if (( RSC > SMART_REALLOCATED_LIMIT )); then
            DISK_ISSUES+="⚠️ Reallocated Sectors (ID 5): ${RSC} (Порог: ${SMART_REALLOCATED_LIMIT})\n"
        elif PREV=$(check_growth "${KEY}_5" "$RSC"); then
            DISK_ISSUES+="⚠️ Reallocated Sectors (ID 5) выросли: ${PREV} → ${RSC}\n"
        fi

        PSC=$(get_attr "$OUT" 197)
        if (( PSC > SMART_PENDING_LIMIT )); then
            DISK_ISSUES+="⚠️ Pending Sectors (ID 197): ${PSC}\n"
        fi

        OU=$(get_attr "$OUT" 198)
        if (( OU > 0 )); then
            DISK_ISSUES+="⚠️ Offline Uncorrectable (ID 198): ${OU}\n"
        fi

        # Накопительные счётчики: само значение может быть историческим,
        # сигнал — именно рост.
        if has_attr "$OUT" 187; then
            RU=$(get_attr "$OUT" 187)
            if PREV=$(check_growth "${KEY}_187" "$RU"); then
                DISK_ISSUES+="⚠️ Reported Uncorrectable (ID 187) вырос: ${PREV} → ${RU}\n"
            fi
        fi
        if has_attr "$OUT" 199; then
            CRC=$(get_attr "$OUT" 199)
            if PREV=$(check_growth "${KEY}_199" "$CRC"); then
                DISK_ISSUES+="⚠️ UDMA CRC (ID 199) вырос: ${PREV} → ${CRC} — кабель/бэкплейн/контроллер\n"
            fi
        fi

        if [[ "$IS_SSD" -eq 0 ]]; then
            SR=$(get_attr "$OUT" 10)
            if (( SR > 0 )); then
                DISK_ISSUES+="⚠️ Spin Retry (ID 10): ${SR} — проблемы раскрутки/питания\n"
            fi
        else
            # Износ SATA SSD: у вендоров разные ID, но нормализованное VALUE
            # у всех — остаток ресурса в % (100 → 0). Только для SSD: на HDD
            # те же ID означают другое (напр. 202 у WD).
            for id in 231 233 177 202 169; do
                if has_attr "$OUT" "$id"; then
                    LEFT=$(get_attr_value "$OUT" "$id")
                    if (( LEFT <= 100 && 100 - LEFT >= SMART_WEAR_LIMIT )); then
                        DISK_ISSUES+="⚠️ Износ SSD (ID ${id}): осталось ${LEFT}% (Порог износа: ${SMART_WEAR_LIMIT}%)\n"
                    fi
                    break
                fi
            done
        fi
    fi

    if [[ -n "$DISK_ISSUES" ]]; then
        REPORT+=" *Disk ${LABEL}* \`${MODEL:-?} ${SERIAL:-}\`:\n${DISK_ISSUES}\n"
        HAS_ERROR=1
    fi

    # === Детект зависания/сброса за последние N минут ===
    # SMART тут бессилен: health остаётся PASSED, пока диск не завис "насмерть".
    # Паттерны привязаны к конкретному устройству, чтобы сбой одного диска не
    # давал алерт по всем.
    PATTERN=""
    if [[ "$IS_NVME" -eq 1 ]]; then
        CTRL=$(echo "$KDEV" | sed -E 's/n[0-9]+$//')
        # Не просто "timeout": драйвер на КАЖДОЙ загрузке пишет информационное
        # "nvme nvme0: Shutdown timeout set to 10 seconds" — это не сбой, а
        # ложный алерт после любой перезагрузки. Реальный таймаут команды
        # выглядит как "I/O 123 QID 4 timeout, aborting/reset controller".
        PATTERN="nvme ${CTRL}: .*(I/O [0-9]+ .*timeout|reset controller|controller is down|Device not ready|Removing after probe failure)"
        PATTERN+="|${CTRL}n[0-9]+: (Read|Write|I/O Cmd)\(.*(Error|status)"
        PATTERN+="|I/O error, dev ${CTRL}n[0-9]+,"
    elif [[ -e "/sys/block/${KDEV}" ]]; then
        # Ошибки ATA ядро пишет по имени порта ("ata3.00: ..."), а не sdX —
        # находим порт через sysfs.
        PORT=$(readlink -f "/sys/block/${KDEV}/device" | grep -oE '/ata[0-9]+/' | tr -d '/')
        [[ -n "$PORT" ]] && PATTERN="${PORT}(\.[0-9]+)?: .*(exception Emask|hard resetting link|failed command|link is slow to respond)|"
        # "I/O error, dev sda," — формат ядер 5.x+, старые писали его же
        # после "blk_update_request: "
        PATTERN+="I/O error,? (on )?dev ${KDEV}[0-9]*,"
        PATTERN+="|\[${KDEV}\] .*(FAILED Result|Sense Key : (Medium|Hardware) Error|timing out command)"
    fi
    # Диски за HW-RAID (/dev/bus/N, megaraid) в журнале ядра по имени не
    # видны — для них остаются только SMART-проверки выше.

    if [[ -n "$PATTERN" ]]; then
        RECENT_HANG=$(echo "$KLOG" | grep -E "$PATTERN" | tail -5)
        if [[ -n "$RECENT_HANG" ]]; then
            HANG_REPORT+=" *${LABEL}* — признаки зависания/сброса за последние ${SMART_LOOKBACK_MIN} мин:\n\`\`\`\n${RECENT_HANG}\n\`\`\`\n"
            HAS_HANG=1
        fi
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
