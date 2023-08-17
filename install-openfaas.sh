#!/bin/bash
set -e

cd ~

#installing open-faas
cat <<EOF > install-openfaas.sh
#!/bin/bash
set -ex
git clone https://github.com/openfaas/faasd --depth=1
cd faasd
./hack/install.sh
EOF

chmod +x install-openfaas.sh
./install-openfaas.sh >> install-openfaas.log 2>&1

#installing docker
cat <<EOF > install-docker.sh
#!/bin/bash
set -ex
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker root
systemctl enable docker
systemctl start docker
EOF

chmod +x install-docker.sh
./install-docker.sh >> install-docker.log 2>&1

#installing aws-cli
cat <<EOF > install-aws-cli.sh
#!/bin/bash
snap install aws-cli --classic
EOF

chmod +x install-aws-cli.sh
./install-aws-cli.sh >> install-aws-cli.log 2>&1
