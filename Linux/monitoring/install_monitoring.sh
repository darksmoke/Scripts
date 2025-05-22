#!/usr/bin/env bash
# --- install_monitoring.sh ---
set -e

# *** Настраиваемые переменные ***
INSTALL_DIR="${1:-/root/scripts/monitoring}"
RAW_BASE="https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring"
FILES=(check_disk.sh check_ram.sh check_cpu.sh check_iowait.sh \
       check_uptime.sh check_raid.sh check_temp.sh check_swap.sh \
       check_smart.sh send_telegram.sh)

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

# config.ini шаблон — создаём, если нет
if [[ ! -f config.ini ]]; then
  cat > config.ini <<EOF
TOKEN=
CHAT_ID=
EOF
  echo "⚠️  Fill your Telegram TOKEN and CHAT_ID in $INSTALL_DIR/config.ini"
fi

# ----------  CRON  ----------
echo "🕒 Configuring cron jobs..."

declare -A PERIOD
PERIOD[check_smart.sh]="60 * * * *"
PERIOD[check_raid.sh]="*/10 * * * *"
PERIOD[check_temp.sh]="*/10 * * * *"
# остальные по 5 мин
for s in check_disk.sh check_ram.sh check_cpu.sh check_iowait.sh check_uptime.sh check_swap.sh; do
  PERIOD[$s]="*/5 * * * *"
done

# Сохраняем текущий crontab
crontab -l 2>/dev/null > /tmp/cron_backup.$$ || true

# Добавляем недостающие строки
UPDATED=0
for script in "${FILES[@]}"; do
  [[ $script == send_telegram.sh ]] && continue
  ENTRY="${PERIOD[$script]} bash $INSTALL_DIR/$script"
  grep -F "$ENTRY" /tmp/cron_backup.$$ >/dev/null || {
    echo "$ENTRY" >> /tmp/cron_backup.$$
    UPDATED=1
  }
done

[[ $UPDATED -eq 1 ]] && crontab /tmp/cron_backup.$$

rm /tmp/cron_backup.$$     # чистим за собой

echo "✅ Installation complete."
