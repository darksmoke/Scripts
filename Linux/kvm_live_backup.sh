#!/usr/bin/env bash
#
# ver. 0.1
#
backup_dir=/KVM/backup
# Список работающих VM
vm_list=`virsh list | grep running | awk '{print $2}'`
# Список VM, заданных вручную, через пробел
#vm_list=(vm1 vm2)
# Лог файл
logfile="/var/log/kvmbackup.log"
keep_days=10

if [[ 1 -lt $(dpkg --list | grep -c pigz) ]]; then echo "Please, install pigz (apt install pigz)" && exit 0; fi

data=`date +%Y-%m-%d_%H-%M-%S`
# Использовать это условие, если список VM задается вручную
#for activevm in "${vm_list[@]}";
# Использовать это условие, если список работающих VM берется автоматически
i=0

for activevm in $vm_list
do
    mkdir -p $backup_dir/$activevm
    echo "`date +"%Y-%m-%d_%H-%M-%S"` Start backup $activevm" >> $logfile
    virsh dumpxml $activevm > $backup_dir/$activevm/$activevm-$data.xml
    echo "`date +"%Y-%m-%d_%H-%M-%S"` Create snapshots $activevm" >> $logfile

    disk_list=`virsh domblklist $activevm | grep vd | awk '{print $1}'`
    disk_path=`virsh domblklist $activevm | grep vd | awk '{print $2}'`

    virsh snapshot-create-as --domain $activevm snapshot --disk-only --atomic --quiesce --no-metadata

    if [ $? -eq 0 ]; then

        for path in $disk_path
        do
            echo "`date +"%Y-%m-%d_%H-%M-%S"` Create backup $activevm $path" >> $logfile
            filename=`basename $path`
            pigz -c $path > $backup_dir/$activevm/$filename-$data.gz
            sleep 2
        done

        for disk in $disk_list
        do
            snap_path=`virsh domblklist $activevm | grep $disk | awk '{print $2}'`
            echo "`date +"%Y-%m-%d_%H-%M-%S"` Commit snapshot $activevm $snap_path" >> $logfile

            virsh blockcommit $activevm $disk --active --verbose --pivot

    	    if [ $? -eq 0 ]; then
                echo "`date +"%Y-%m-%d_%H-%M-%S"` Delete snapshot $activevm $snap_path" >> $logfile
                rm $snap_path
                echo "`date +"%Y-%m-%d_%H-%M-%S"` End backup $activevm \n" >> $logfile
            else
              i=$(( i+1 ))
              echo "`date +"%Y-%m-%d_%H-%M-%S"` PROBLEM 1! $activevm" >> $logfile
            fi

        done
    else
    	i=$(( i+1 ))
    	echo "`date +"%Y-%m-%d_%H-%M-%S"` PROBLEM 2! $activevm $snap_path" >> $logfile
    fi

    if [ $i -gt 0 ]; then
        echo "`date +"%Y-%m-%d_%H-%M-%S"` COUNT PROBLEMS = $i \n" >> $logfile
    fi
done

if [ $i -eq 0 ]; then
    /usr/bin/find $backup_dir -type f -mtime +${keep_days} -exec rm -rf {} \;
fi

#
# Сжать файл file.ext в /tmp/file.ext.gz с сохранением (-k) оригинального файла:
# pigz -k -c file.ext > /tmp/file.ext.gz
#
# Распаковать (-d) файл file.ext.gz с сохранением (-k) архива:
# pigz -k -d file.ext.gz
#
# Распаковать (-d) файл file.ext.gz в файл /tmp/file.ext с сохранением (-k) архива:
# pigz -k -c -d file.ext.gz >/tmp/file.ext
