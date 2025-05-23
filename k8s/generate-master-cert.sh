#!/bin/bash

openssl genrsa -out apiserver.key 2048
openssl req -new -key apiserver.key -config master_ssl.cnf -subj="/CN=apiserver" -out apiserver.csr
openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 36500 -extensions v3_req -extfile master_ssl.cnf -out apiserver.crt
