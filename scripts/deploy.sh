#!/bin/bash

PROJECT_DIR=

if [ ! -e "$PROJECT_DIR" ];then
    mkdir -p "$PROJECT_DIR"
fi

rm "${PROJECT_DIR}/index.html"
rm "${PROJECT_DIR}/asset-manifest.json"
rm -rf "${PROJECT_DIR}/static"


tar -xf tar --strip-components=1 -C "$PROJECT_DIR"


