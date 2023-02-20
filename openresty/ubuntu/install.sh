#!/bin/bash
sudo apt-get -y install --no-install-recommends wget gnupg ca-certificates
wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/openresty-keyring.gpg ] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list
sudo apt install -y openresty
