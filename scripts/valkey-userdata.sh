#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -ex

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Run Valkey 9
docker pull valkey/valkey:9
docker run -d --name valkey-server --network host valkey/valkey:9 valkey-server --bind 0.0.0.0 --protected-mode no --save "" --appendonly no

echo "VALKEY_READY" > /tmp/setup-status
