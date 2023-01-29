import pysftp
import re
import os
import requests
from secrets import *


username = hatzner_username
password = hatzner_password
hostname = hatzner_username + ".your-storagebox.de"

path_backup_dir = "/Users/aleksejsidorin"

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

    small_data = arch_data[0] if arch_data else None

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
        message = "Файл загрузился успешно."
    else:
        message = "Рамер файлов не совпадает. Что-то пошло не так..."


url = f"https://api.telegram.org/bot{TOKEN}/sendMessage?chat_id={chat_id}&text={message}"
requests.get(url).json()

# Get info
# url = f"https://api.telegram.org/bot{TOKEN}/getUpdates"
# print(requests.get(url).json())
