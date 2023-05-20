#!/bin/sh
if [ ! -d '/var/backups/mysqlbackup'] ; then
	mkdir /var/backups/mysqlbackup
fi
xtrabackup -udiqi_db_xtrabackup -pBagEvent6115510637  --backup --target-dir=/var/backups/mysqlbackup
