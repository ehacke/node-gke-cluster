#!/usr/bin/env bash

if [ -z "$MAX_MEM_BYTES" ]; then
  echo "variable MAX_MEM_BYTES must be supplied!!!"
  exit 1
fi

sed -ri "s|maxmemory <bytes>|maxmemory ${MAX_MEM_BYTES}|g"  /redis/redis.conf
echo "Starting as redis with config file..."
redis-server /redis/redis.conf