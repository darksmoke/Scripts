#!/bin/bash
set -e

# === Конфигурация ===
INSTALL_DIR="${1:-/root/scripts/monitoring}"
CONFIG_FILE="$INSTALL_DIR/config.ini"
RAW_BASE="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring"
FILES=(check_disk.sh check_ram.sh check_cpu.sh check_iowait.sh check_uptime.sh check_raid.sh check_temp.sh check_swap.sh check_smart.sh send_telegram.sh)

echo "📁 Target directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📦 Installing required packages..."
apt update -y
apt install -y curl wget git smartmontools lm-sensors util-linux mdadm bc sysstat

echo "⬇️  Downloading monitoring scripts..."
for f in "${FILES[@]}"; do
  echo "   - $f"
  curl -fsSL "$RAW_BASE/$f" -o "$f"
  chmod +x "$f"
done

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "📝 Creating config.ini..."
    cat <<EOF > "$CONFIG_FILE"
[telegram]
TOKEN=
CHAT_ID=
EOF
else
    echo "🔧 config.ini already exists, skipping creation."
fi

# === Настройка crontab ===
echo "🛠 Updating crontab..."
TMP_CRON=$(mktemp)

# Получаем текущие задачи и удаляем все, связанные с monitoring
crontab -l 2>/dev/null | grep -v "$INSTALL_DIR" | grep -v "install_monitoring.sh" > "$TMP_CRON" || true

# Добавляем комментарий перед блоком заданий мониторинга
echo "# https://github.com/darksmoke/Scripts/tree/main/Linux/monitoring" >> "$TMP_CRON"

# Добавляем задачи для скриптов
for script in "${FILES[@]}"; do
  [[ "$script" == "send_telegram.sh" ]] && continue

  case "$script" in
    check_smart.sh) CRON_EXPR="0 * * * *" ;;  # 1 раз в час
    *) CRON_EXPR="*/5 * * * *" ;;              # каждые 5 минут
  esac

  ENTRY="$CRON_EXPR bash $INSTALL_DIR/$script"

  if ! grep -Fq "$ENTRY" "$TMP_CRON"; then
    echo "$ENTRY" >> "$TMP_CRON"
    echo "➕ Added: $ENTRY"
  else
    echo "✅ Already exists: $ENTRY"
  fi
done

# === Добавление автообновления ===
UPDATE_ENTRY="0 3 * * * bash <(curl -s https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring/install_monitoring.sh)"
if ! grep -Fq "$UPDATE_ENTRY" "$TMP_CRON"; then
  echo "$UPDATE_ENTRY" >> "$TMP_CRON"
  echo "🕒 Added daily auto-update: $UPDATE_ENTRY"
else
  echo "✅ Auto-update already scheduled."
fi

# Установка обновлённого crontab
crontab "$TMP_CRON"
rm "$TMP_CRON"
echo "✅ Installation and crontab update complete."
