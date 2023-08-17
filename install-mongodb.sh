#!/bin/bash
set -e

apt-get install gnupg curl >> ~/install-mongo.log 2>&1

curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
   gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg \
   --dearmor >> ~/install-mongo.log 2>&1

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list >> ~/install-mongo.log 2>&1

apt-get update >> ~/install-mongo.log 2>&1

apt-get install -y mongodb-org >> ~/install-mongo.log 2>&1

systemctl start mongod >> ~/install-mongo.log 2>&1

systemctl status mongod >> ~/install-mongo.log 2>&1

systemctl enable mongod >> ~/install-mongo.log 2>&1
