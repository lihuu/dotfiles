#!/bin/bash
ramdisk_size_in_mb=8192
mount_point=/private/tmp

ramdisk_size_in_sectors=$((${ramdisk_size_in_mb}*1024*1024/512))

ramdisk_dev_file=`hdid -nomount ram://${ramdisk_size_in_sectors}`
newfs_hfs -v 'Ramdisk' ${ramdisk_dev_file}
mkdir -p ${mount_point}
mount -o rw,noatime,nobrowse -t hfs ${ramdisk_dev_file} ${mount_point}
chown root:wheel ${mount_point}
chmod 1777 ${mount_point}
mkdir ${mount_point}/Chrome
chmod 1777 ${mount_point}/Chrome
