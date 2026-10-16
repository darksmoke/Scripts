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
| **CPU Load** | Checks 5-min Load Average based on core count | Проверка Load Average (5 мин) с учетом кол-ва ядер | Every 5 min |
| **RAM Usage** | Alerts if available RAM (`MemAvailable`) is low | Уведомление, если доступной RAM (`MemAvailable`) мало | Every 5 min |
| **Disk Space** | Free space and inodes per filesystem, excludes snaps/tmpfs; alerts if `df` hangs (stale NFS) | Свободное место и inode, исключая snap/tmpfs; алерт, если `df` завис (NFS) | Every 5 min |
| **IO Wait** | Detects disk bottlenecks | Обнаружение проблем с дисковой подсистемой | Every 5 min |
| **Temperature** | CPU/System temperature checks (`sensors`) | Проверка температуры компонентов | Every 5 min |
| **SWAP** | Alerts on high SWAP usage | Уведомление при высоком использовании SWAP | Every 5 min |
| **S.M.A.R.T.** | Disk health for HDD/SATA SSD/SAS/NVMe and disks behind HW-RAID (`smartctl --scan-open`), SSD wear, error counter growth; per-device controller hang/reset detection in the kernel log; the hang alert bypasses the maintenance window | Здоровье дисков HDD/SATA SSD/SAS/NVMe и за HW-RAID, износ SSD, рост счётчиков ошибок; детект зависаний/сбросов по логу ядра для каждого диска; алерт о зависании не глушится окном обслуживания | Every 5h |
| **RAID** | Monitors Linux Software RAID (`mdadm`) status | Мониторинг состояния Software RAID (`mdadm`) | Hourly |
| **Uptime** | Detects recent reboots | Оповещение о недавней перезагрузке сервера | Every 10 min |
| **Reboot required** | `/var/run/reboot-required` or running kernel older than installed | Требуется перезагрузка: флаг или запущенное ядро старше установленного | Daily 08:00 |
| **QEMU Agent** | Guest agent responds in running VMs (libvirt) | Отвечает ли guest agent в запущенных ВМ (libvirt) | Daily 09:00 |

## 🛠 Installation / Установка

### Option 1: Automatic (via curl)
*(Replace URL with your actual repository URL)*

```bash
curl -s https://raw.githubusercontent.com/darksmoke/Scripts/main/Linux/monitoring/install.sh | bash
```

