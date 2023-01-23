#!/usr/bin/env bash
#
# ver. 0.1
#
backup_dir=/KVM/backup
keep_days=7

# VMName="Windows_2019_official" # Single name of VM
VMName=`virsh list | grep running | awk '{print $2}'`


if [[ 1 -lt $(dpkg --list | grep -c pigz) ]]; then echo "Please, install pigz (apt install pigz)" && exit 0; fi

data=`date +%Y-%m-%d_%H-%M-%S`


for activevm in $VMName
do
    mkdir -p $backup_dir/$activevm
    virsh suspend --domain $activevm
    sleep 2
    virsh dumpxml $activevm > $backup_dir/$activevm/$activevm-$data.xml
    disk_path=`virsh domblklist $activevm | grep vd | awk '{print $2}'`

    for path in $disk_path
    do
	filename=`basename $path`
	pigz -k -c $path > $backup_dir/$activevm/$filename-$data.gz
	sleep 2
    done

    virsh resume --domain $activevm
done


if [ $(ls *.gz $backup_dir | wc -l) -ge 2 ]; then
    /usr/bin/find $backup_dir -type f -mtime +${keep_days} -exec rm -rf {} \;
fi
