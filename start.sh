#!/bin/bash

# 启动 Casdoor 后端
echo "Starting Casdoor backend..."
cd "$(dirname "$0")"
make run &

# 等待 Casdoor 启动
echo "Waiting for Casdoor to start..."
sleep 5

# 启动 Traefik
echo "Starting Traefik..."
traefik --configfile=traefik_casdoor_config.yaml
