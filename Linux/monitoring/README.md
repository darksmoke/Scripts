# Linux Monitoring Scripts 🖥️📡

A set of modular Bash scripts for monitoring critical system health metrics on Linux servers with Telegram alerting.

## 🔧 Features

- 🔍 Disk space monitoring (alert if partition < 10%)
- 🧠 RAM usage check (alert if free RAM < 5%)
- 🧮 CPU load check (alert if high load persists)
- 🚦 IO wait monitoring
- 🔁 Uptime check (detect if system rebooted < 1h ago)
- 🧱 RAID status monitoring
- 🌡 CPU temperature alert
- 🧊 Swap usage alert
- 📦 SMART status check for disk health
- 📲 Telegram notifications with Markdown formatting

## 📦 Requirements

- Bash
- `curl`, `wget`
- `smartmontools`, `lm-sensors`, `mdadm`, `util-linux`

## 🚀 Installation

Run the following command (by default installs into `/root/scripts/monitoring`):

```bash
bash <(curl -s https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring/install_monitoring.sh)
```

## ⚙️ Configuration

Create a `config.ini` file in the folder:

```ini
TOKEN=your_telegram_bot_token
CHAT_ID=your_telegram_chat_id
```

## 🕒 Cron Integration

Each script is registered to run every 5–60 minutes via `crontab`.

## 📄 Scripts

| Script              | Description                       |
|---------------------|-----------------------------------|
| check_disk.sh       | Disk space monitoring             |
| check_ram.sh        | RAM usage monitoring              |
| check_cpu.sh        | CPU load monitoring               |
| check_iowait.sh     | IO wait monitoring                |
| check_uptime.sh     | Reboot check                      |
| check_raid.sh       | RAID status check                 |
| check_temp.sh       | CPU temperature monitoring        |
| check_swap.sh       | Swap usage monitoring             |
| check_smart.sh      | SMART disk health check           |

---

# Скрипты мониторинга для Linux 🐧

Набор Bash-скриптов для мониторинга состояния Linux-серверов с отправкой уведомлений в Telegram.

## 🔧 Возможности

- 📉 Мониторинг свободного места (если < 10%)
- 🧠 Проверка свободной ОЗУ (если < 5%)
- 🧮 Загрузка CPU (если долго высокая)
- 🚦 Высокий IO Wait
- 🔁 Перезагрузка менее часа назад
- 🧱 Проверка состояния RAID
- 🌡 Температура процессора
- 🧊 Использование swap
- 💽 SMART проверка здоровья дисков
- 📲 Уведомления в Telegram с разметкой Markdown

## 📦 Требования

- Bash
- `curl`, `wget`
- `smartmontools`, `lm-sensors`, `mdadm`, `util-linux`

## 🚀 Установка

По умолчанию в `/root/scripts/monitoring`:

```bash
bash <(curl -s https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring/install_monitoring.sh)
```

## ⚙️ Настройка

Создай файл `config.ini`:

```ini
TOKEN=токен_тг_бота
CHAT_ID=id_чата_или_канала
```

## 🕒 Интеграция в Cron

Все скрипты автоматически регистрируются в crontab с частотой от 5 до 60 минут.

## 📄 Скрипты

| Скрипт              | Описание                          |
|---------------------|-----------------------------------|
| check_disk.sh       | Свободное место                   |
| check_ram.sh        | Свободная оперативная память      |
| check_cpu.sh        | Загрузка процессора               |
| check_iowait.sh     | Высокий IO Wait                   |
| check_uptime.sh     | Недавняя перезагрузка             |
| check_raid.sh       | Состояние RAID массива            |
| check_temp.sh       | Температура процессора            |
| check_swap.sh       | Использование SWAP                |
| check_smart.sh      | SMART проверка здоровья дисков    |
