#!/bin/bash

apt-get update -y
apt-get install -y git

# Clone the repo directly (any updates made to the setup script won't require manual change on vultr)
git clone -b das-1033/add-userdata-script https://github.com/singnet/das-pre-infra-vultr.git /tmp/setup-server

# Run script
bash /tmp/setup-server/vultr_userdata/setup_server.sh

# Delete files after use.
rm -rf /tmp/setup-server/