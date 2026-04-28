#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -ex

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Run Redis 7.2
docker pull redis:7.2
docker run -d --name redis-server --network host redis:7.2 redis-server --bind 0.0.0.0 --protected-mode no --save "" --appendonly no

echo "REDIS72_READY" > /tmp/setup-status
