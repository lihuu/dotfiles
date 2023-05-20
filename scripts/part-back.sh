#!/bin/bash
BakDir=/home/lihu/backup/
BinDir=/var/log/mysql                           
LogFile=/home/lihu/backup/bak.log
BinFile=/var/log/mysql/mysql-bin.index           

mysqladmin -uroot -proot flush-logs
Counter=`wc -l $BinFile |awk '{print $1}'`
NextNum=0
for file in `cat $BinFile`
do
	base=`basename $file`
	NextNum=`expr $NextNum + 1`
	if [ $NextNum -eq $Counter ]
	then
		echo $base skip! >> $LogFile
	else
		dest=$BakDir/$base
		if(test -e $dest)
		then
			echo $base exist! >> $LogFile
		else
			cp $BinDir/$base $BakDir
			echo $base copying >> $LogFile
		fi
	fi
done

