#!/bin/bash

while getopts "h:" opt;do
    case $opt in 
        h) host=$OPTARG;;
    esac
done

if [ -z "$host" ];then
    echo "usage: ./copy-ssh-pub-keys.sh -h <your host>"
    exit 1
fi

cat ~/.ssh/id_rsa.pub| ssh $host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
