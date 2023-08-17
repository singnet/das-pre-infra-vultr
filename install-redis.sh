#!/bin/bash
set -e

apt update                              >> ~/install-redis.log 2>&1
apt install -y redis-server redis-tools >> ~/install-redis.log 2>&1
systemctl start redis-server            >> ~/install-redis.log 2>&1
systemctl enable redis-server           >> ~/install-redis.log 2>&1
systemctl status redis-server           >> ~/install-redis.log 2>&1
