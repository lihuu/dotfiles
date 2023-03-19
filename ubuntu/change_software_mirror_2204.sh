#!/bin/sh

sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo cp ./mirror_2204_tuna.text /etc/apt/sources.list
sudo apt update

