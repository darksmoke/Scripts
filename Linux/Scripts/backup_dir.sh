#!/usr/bin/env bash
backup_dir=/tank/backup
backup_source="/tank/samba/share1 /tank/samba/share2"
keep_day=7

date=$(date '+%Y-%m-%d')

mkdir -p $backup_dir
cd $backup_dir
for dir_name in $backup_source
do
    zip -r ${dir_name}_${date}.zip $dir_name
    mv ${dir_name}_${date}.zip $backup_dir
done

/usr/bin/find $backup_dir -type f -mtime +${keep_day} -exec rm -rf {} \;
