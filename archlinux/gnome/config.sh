#!/bin/bash
gsettings set  org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
sudo pacman -S mutter-x11-scaling gnome-control-center-x11-scaling

