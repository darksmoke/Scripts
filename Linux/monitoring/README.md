# Linux Bash Monitoring with Telegram Alerts 📊🚀

A lightweight, modular set of Bash scripts for monitoring Linux server health metrics. It sends real-time notifications to Telegram when thresholds are exceeded.

**Key Features:**
* 🔍 **Zero heavy dependencies:** Uses standard tools (`awk`, `df`, `free`, `sysstat`).
* ⚙️ **Centralized Config:** One file to rule them all (`config.sh`).
* 🛡️ **Clean Cron:** Uses `/etc/cron.d/monitoring` to prevent duplicate jobs.
* 📱 **Telegram Alerts:** Fast and formatted notifications.

---

# Скрипты мониторинга Linux с уведомлениями в Telegram 📊🚀

Легкий и модульный набор Bash-скриптов для мониторинга состояния Linux-серверов. Отправляет уведомления в Telegram в реальном времени при превышении пороговых значений.

**Ключевые особенности:**
* 🔍 **Без тяжелых зависимостей:** Использует стандартные утилиты (`awk`, `df`, `free`, `sysstat`).
* ⚙️ **Централизованная настройка:** Все настройки в одном файле (`config.sh`).
* 🛡️ **Чистый Cron:** Использует системный `/etc/cron.d/monitoring`, что исключает дублирование задач.
* 📱 **Telegram уведомления:** Быстрые и отформатированные сообщения.

---

## 📋 Features / Возможности

| Feature | Description (EN) | Описание (RU) | Cron Schedule |
| :--- | :--- | :--- | :--- |
| **CPU Load** | Checks 1-min Load Average based on core count | Проверка Load Average (1 мин) с учетом кол-ва ядер | Every 5 min |
| **RAM Usage** | Alerts if free RAM is low | Уведомление, если свободной RAM мало | Every 5 min |
| **Disk Space** | Monitors specific filesystems, excludes snaps/tmpfs | Мониторинг места, исключая snap/tmpfs | Every 5 min |
| **IO Wait** | Detects disk bottlenecks | Обнаружение проблем с дисковой подсистемой | Every 5 min |
| **Temperature** | CPU/System temperature checks (`sensors`) | Проверка температуры компонентов | Every 5 min |
| **SWAP** | Alerts on high SWAP usage | Уведомление при высоком использовании SWAP | Every 5 min |
| **S.M.A.R.T.** | Checks physical disk health (HDD/SATA SSD/NVMe) and detects controller hangs/resets in the kernel log; the hang alert bypasses the maintenance window | Проверка здоровья дисков (HDD/SATA SSD/NVMe) и детект зависаний/сбросов контроллера по логу ядра; алерт о зависании не глушится окном обслуживания | Every 5h |
| **RAID** | Monitors Linux Software RAID (`mdadm`) status | Мониторинг состояния Software RAID (`mdadm`) | Hourly |
| **Uptime** | Detects recent reboots | Оповещение о недавней перезагрузке сервера | Every 5 min |

## 🛠 Installation / Установка

### Option 1: Automatic (via curl)
*(Replace URL with your actual repository URL)*

```bash
curl -s https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring/install.sh | bash
```

