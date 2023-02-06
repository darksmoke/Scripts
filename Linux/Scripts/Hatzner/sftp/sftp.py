import pysftp
import re
import os
import requests
import time
from secrets import *

start_time = time.time()

username = hatzner_username
password = hatzner_password
hostname = hatzner_username + ".your-storagebox.de"

path_backup_dir = "/tank/backup"

prefix = "samba_"  # samba_2023-01-20.zip
file_extension = ".zip"

TOKEN = api_key
chat_id = "279295357"


def get_files(all_files):
    name_arch_files = list()
    for item in all_files:
        name_arch_files += re.findall(r'' + prefix + '[0-9]{4}-[0-9]{2}-[0-9]{2}' + file_extension, item)
    return name_arch_files


def serch_new_file(arch_data):
    for item in arch_data:
        if item > small_data:
            small_data = item
    return small_data


def upload_file():
    sftp.put(path_backup_dir + '/' + prefix + small_data + file_extension, preserve_mtime=True)


with pysftp.Connection(hostname, username=username, password=password) as sftp:
    all_files = sftp.listdir()

    arch_data = list()
    for item in get_files(all_files):
        arch_data += re.findall(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', item)

    small_data = arch_data[0] if arch_data else "1000-01-01"

    if len(arch_data) >= 4:
        # Найти самый старый файл и удалить
        for item in arch_data:
            if item < small_data:
                small_data = item

        sftp.remove(prefix + small_data + file_extension)

    # Загружаем новый файл
    local_files = os.listdir(path_backup_dir)

    for item in get_files(local_files):
        arch_data += re.findall(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', item)

    # Найти самый новый файл
    for item in arch_data:
        if item > small_data:
            small_data = item

    stats = os.stat(path_backup_dir + '/' + prefix + small_data + file_extension)
    size_local_file = stats.st_size

    sftp.put(path_backup_dir + '/' + prefix + small_data + file_extension, preserve_mtime=True)

    file_attr = str(sftp.stat(prefix + small_data + file_extension))
    size_remoute_file = int(file_attr.split()[4])

    if size_remoute_file == size_local_file:
        message = f"Файл, {prefix + small_data + file_extension}, загрузился успешно."
    else:
        message = "Рамер файлов не совпадает. Что-то пошло не так..."

    url = f"https://api.telegram.org/bot{TOKEN}/sendMessage?chat_id={chat_id}&text={message}"
    requests.get(url).json()

    all_files = sftp.listdir()
    filies_on_server = get_files(all_files)
    filies_on_server = '\n'.join(filies_on_server)

    url = f"https://api.telegram.org/bot{TOKEN}/sendMessage?chat_id={chat_id}&text=Список файлов на сервере:\n{filies_on_server}"
    requests.get(url).json()


time_format = time.strftime("%H:%M:%S", time.gmtime(time.time() - start_time))
url = f"https://api.telegram.org/bot{TOKEN}/sendMessage?chat_id={chat_id}&text=Скрипт выполнянлся: {time_format}"
requests.get(url).json()

# Get info
# url = f"https://api.telegram.org/bot{TOKEN}/getUpdates"
# print(requests.get(url).json())
