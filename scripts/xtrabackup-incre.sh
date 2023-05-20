#!/bin/sh
back_base_dir=/var/backups/mysqlbackup
incre_dir=$back_base_dir/`date '+%Y-%m-%d-%H%M%S'`

xtrabackup -udiqi_db_xtrabackup -pBagEvent6115510637  --backup --target-dir=$incre_dir  --incremental-basedir=$back_base_dir
