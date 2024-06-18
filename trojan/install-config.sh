#!/bin/sh

rootDir=$(git rev-parse --show-toplevel)

if [ ! -e /etc/systemd/system/trojan-go.service ];then
    echo "Will copy trojan-go.service to /etc/systemd/system"
    sudo cp $rootDir/trojan/trojan-go.service /etc/systemd/system/
fi

if [ ! -d /etc/trojan-go ];then
    echo "Will create folder /etc/trojan-go"
    sudo mkdir /etc/trojan-go
fi

if [ ! -e /etc/trojan-go/client.json ];then
    echo "Will copy client.json to /etc/trojan-go"
    sudo cp $rootDir/trojan/client.json /etc/trojan-go/
fi


if [ ! -d /usr/share/trojan-go ];then
    echo "Will create folder /usr/share/trojan-go"
    sudo mkdir /usr/share/trojan-go
fi


echo "DONE"

