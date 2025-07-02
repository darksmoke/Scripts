#!/bin/bash
#
# Скрипт для проверки состояния дисков (S.M.A.R.T.)
# и отправки уведомления в Telegram.
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

# Проверяем, существует ли smartctl в системе
if ! command -v smartctl &> /dev/null; then
    echo "INFO: Команда 'smartctl' не найдена. Установите 'smartmontools'. Проверка не выполняется."
    exit 0
fi

# --- Функции ---

# Более надежная функция для извлечения RAW_VALUE атрибута S.M.A.R.T.
# $1 - вывод 'smartctl -A', $2 - ID атрибута
get_smart_attribute() {
    local smart_output="$1"
    local attribute_id="$2"
    # Ищем строку, начинающуюся с ID, и берем 10-е поле. Возвращаем 0, если атрибут не найден.
    echo "$smart_output" | awk -v id="$attribute_id" '$1 == id {print $10; exit}' | sed 's/^0*//' || echo 0
}


# --- Основная логика ---

echo "Начало проверки S.M.A.R.T. дисков..."

# Получаем список физических дисков
# Исключаем диски md, loop, sr (CD-ROM)
DISKS=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}')

for disk in $DISKS; do
    echo "  - Проверка диска: ${disk}"
    
    # Переменная для сбора проблем по текущему диску
    PROBLEM_REPORT=""
    
    # 1. Быстрая проверка общего состояния здоровья диска
    # '|| true' нужно, чтобы 'set -e' не прервал скрипт, если команда вернет ошибку
    HEALTH_STATUS=$(smartctl -H "$disk" || true)
    
    if ! echo "$HEALTH_STATUS" | grep -q "PASSED"; then
        echo "!!! КРИТИЧЕСКАЯ ОШИБКА ЗДОРОВЬЯ на диске ${disk}!"
        PROBLEM_REPORT+="*Общий тест здоровья:* FAILED\n"
        # Добавляем полный отчет для диагностики
        PROBLEM_REPORT+="\`\`\`\n$(smartctl -a "$disk")\n\`\`\`"
    else
        # 2. Если общая проверка пройдена, проверяем критичные атрибуты
        echo "    Общий статус: PASSED. Проверка критичных атрибутов..."
        
        ATTRIBUTES_OUTPUT=$(smartctl -A "$disk")
        WARNINGS=()

        # Reallocated Sector Count (ID 5)
        REALLOCATED=$(get_smart_attribute "$ATTRIBUTES_OUTPUT" 5)
        if (( REALLOCATED > SMART_REALLOCATED_SECTOR_CT )); then
            WARNINGS+=("🔴 *Переназначенные сектора (ID 5):* \`${REALLOCATED}\` (Порог: ${SMART_REALLOCATED_SECTOR_CT})")
        fi

        # Current Pending Sector Count (ID 197)
        PENDING=$(get_smart_attribute "$ATTRIBUTES_OUTPUT" 197)
        if (( PENDING > SMART_PENDING_SECTOR_CT )); then
            WARNINGS+=("🔴 *Сектора-кандидаты (ID 197):* \`${PENDING}\` (Порог: ${SMART_PENDING_SECTOR_CT})")
        fi

        # Offline Uncorrectable Sector Count (ID 198)
        UNCORRECTABLE=$(get_smart_attribute "$ATTRIBUTES_OUTPUT" 198)
        if (( UNCORRECTABLE > SMART_UNCORRECTABLE_SECTOR_CT )); then
            WARNINGS+=("🔴 *Неисправимые ошибки (ID 198):* \`${UNCORRECTABLE}\` (Порог: ${SMART_UNCORRECTABLE_SECTOR_CT})")
        fi
        
        # Command Timeout (ID 188)
        TIMEOUT=$(get_smart_attribute "$ATTRIBUTES_OUTPUT" 188)
        if (( TIMEOUT > SMART_COMMAND_TIMEOUT )); then
            WARNINGS+=("🔴 *Таймауты команд (ID 188):* \`${TIMEOUT}\` (Порог: ${SMART_COMMAND_TIMEOUT})")
        fi
        
        # Если были предупреждения по атрибутам, формируем отчет
        if [[ ${#WARNINGS[@]} -gt 0 ]]; then
            PROBLEM_REPORT+="*Превышены пороги критичных атрибутов:*\n"
            PROBLEM_REPORT+=$(printf '%s\n' "${WARNINGS[@]}")
        fi
    fi

    # Если по диску были проблемы (любого типа), отправляем уведомление
    if [[ -n "$PROBLEM_REPORT" ]]; then
        HOST=$(hostname)
        TIME=$(date '+%Y-%m-%d %H:%M:%S')

        MSG=$(cat <<EOF
🔧 *Обнаружены S.M.A.R.T. проблемы на сервере: ${HOST}* 🔧

🕒 *Время:* ${TIME}
💾 *Диск:* \`${disk}\`

*Обнаруженные проблемы:*
${PROBLEM_REPORT}
EOF
)
        echo "Отправка уведомления о проблемах с ${disk} в Telegram..."
        send_telegram "$MSG"
        echo "Уведомление отправлено."
    else
        echo "    Статус: OK"
    fi
done

echo "Проверка S.M.A.R.T. завершена."
exit 0
