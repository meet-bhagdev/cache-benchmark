#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -ex

# Install build dependencies
dnf install -y gcc gcc-c++ make git cmake clang

# Install Rust as ec2-user
sudo -u ec2-user bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'

# Clone and build valkey-lab
sudo -u ec2-user bash -c '
  source /home/ec2-user/.cargo/env
  cd /home/ec2-user
  git clone -b rename-valkey-lab https://github.com/ksmotiv8/cachecannon.git
  cd cachecannon
  cargo build --release --bin valkey-lab 2>&1 | tail -5
'

# Symlink for easy access
ln -sf /home/ec2-user/cachecannon/target/release/valkey-lab /usr/local/bin/valkey-lab

echo "CLIENT_READY" > /tmp/setup-status
