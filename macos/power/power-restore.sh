#!/usr/bin/env bash
set -euo pipefail

echo ">>> Restore default macOS power settings"

sudo pmset -a hibernatemode 3
sudo pmset -a standby 1
sudo pmset -a autopoweroff 1
sudo pmset -a powernap 1
sudo pmset -c sleep 10
sudo pmset -b sleep 10
sudo pmset -a tcpkeepalive 1
sudo pmset -a displaysleep 10

echo ">>> Done"
pmset -g
