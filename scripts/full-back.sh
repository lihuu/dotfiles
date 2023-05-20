#!/bin/bash

if [ ! -d old_backups ] ;then
	mkdir old_backups
fi

mv diqi_db_backup_* old_backups

back_file_dir="/var/backups/mysqlbackup"
if [ ! -d $backup_file_dir ] ; then
	echo "making dirs"
	mkdir -p $backup_file_dir
fi

backup_file_name=diqi_db_backup_`date '+%Y-%m-%d'`.sql.gz
mysqldump -udiqi_db_backup -p'BagEvent6115510637' --single-transaction --flush-logs --master-data=2  diqi_bagevent | gzip > $backup_file_name
if [ -e $backup_file_name ] ;then 
	echo "Start to copy files"
	#scp $backup_file_name  lihu@ubuntu-vm-02:/home/lihu
	rsync -az $backup_file_name -e ssh lihu@ubuntu-vm-03:/home/lihu
	rm old_backups/*.sql.gz
else
	echo "No file to copy"
fi


