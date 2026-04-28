# 🚀 Cache Benchmark: Redis 7.2 vs Redis 8.6 vs Valkey 9.1

A comprehensive performance benchmark comparing **Redis 7.2**, **Redis 8.6**, and **Valkey 9.1** on AWS Graviton4 (c8g) instances using [valkey-lab](https://github.com/ksmotiv8/cachecannon) — a high-performance benchmark tool powered by `io_uring`.

## 📊 [View the Full Interactive Report →](https://meet-bhagdev.github.io/cache-benchmark/)

## Key Findings

| Configuration | Winner | Peak Throughput |
|--------------|--------|-----------------|
| Default (single-threaded I/O) | **Redis 8.6** | 1.95M req/s |
| IO-Threads 6 | **Valkey 9.1** | **2.54M req/s** 🏆 |

- **Redis 8.6 is 50-96% faster than Redis 7.2** in pipelined workloads
- **Valkey 9.1 with io-threads beats Redis 8.6 by 15.5%** in high-throughput scenarios
- **Valkey's IO-thread scaling is dramatically better**: 27-43% gains vs Redis 8.6's 12-19%
- **Under SLO constraints (p99.9 ≤ 1ms), all three are equivalent** at ~178K req/s
- **Zero errors** across all 36 tests — all engines are rock-solid

## Infrastructure

| Component | Spec |
|-----------|------|
| Server Instances | `c8g.2xlarge` (Graviton4, 8 vCPU, 16 GiB) |
| Client Instance | `c8g.4xlarge` (Graviton4, 16 vCPU, 32 GiB) |
| OS | Amazon Linux 2023 (kernel 6.18, ARM64) |
| Region | us-east-1 |
| Network | Same VPC, private IPs, no TLS |
| Benchmark Tool | [valkey-lab](https://github.com/ksmotiv8/cachecannon) (io_uring engine) |

### Server Software (Docker)

| Server | Image | Config |
|--------|-------|--------|
| Redis 7.2 | `redis:7.2` | `--protected-mode no --save "" --appendonly no` |
| Redis 8.6 | `redis:8.6` | `--protected-mode no --save "" --appendonly no` |
| Valkey 9.0/9.1 | `valkey/valkey:9` / `valkey/valkey:9.1.0-rc1` | `--protected-mode no --save "" --appendonly no` |

IO-threads config (Round 2): `--io-threads 6 --io-threads-do-reads yes`

## Reproduce It Yourself

### Prerequisites

- AWS account with permissions to launch EC2 instances
- AWS CLI configured
- A key pair in your target region

### Step 1: Launch Server Instances

Launch 3 `c8g.2xlarge` instances with Amazon Linux 2023 ARM64 AMI. Use the user-data scripts in [`scripts/`](scripts/) to auto-configure each server:

```bash
# Get the latest AL2023 ARM64 AMI
AMI_ID=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-arm64" "Name=state,Values=available" \
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text)

# Create security group
SG_ID=$(aws ec2 create-security-group --group-name cache-bench-sg \
  --description "Cache benchmark" --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 6379 --source-group $SG_ID

# Launch Redis 7.2 server
aws ec2 run-instances --image-id $AMI_ID --instance-type c8g.2xlarge \
  --key-name YOUR_KEY --security-group-ids $SG_ID \
  --user-data file://scripts/redis72-userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=redis72-server}]'

# Launch Redis 8.6 server
aws ec2 run-instances --image-id $AMI_ID --instance-type c8g.2xlarge \
  --key-name YOUR_KEY --security-group-ids $SG_ID \
  --user-data file://scripts/redis-userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=redis86-server}]'

# Launch Valkey 9.1 server
aws ec2 run-instances --image-id $AMI_ID --instance-type c8g.2xlarge \
  --key-name YOUR_KEY --security-group-ids $SG_ID \
  --user-data file://scripts/valkey-userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=valkey-server}]'
```

### Step 2: Launch Client Instance

```bash
aws ec2 run-instances --image-id $AMI_ID --instance-type c8g.4xlarge \
  --key-name YOUR_KEY --security-group-ids $SG_ID \
  --user-data file://scripts/client-userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bench-client}]'
```

The client user-data script installs Rust, clones [cachecannon](https://github.com/ksmotiv8/cachecannon), and builds `valkey-lab`.

### Step 3: Run Benchmarks

SSH into the client instance and update the server IPs in the benchmark scripts, then run:

```bash
# Default config benchmarks
bash scripts/run-benchmarks.sh

# For Redis 7.2
bash scripts/run-redis72-benchmarks.sh

# IO-threads config (after restarting servers with --io-threads 6)
bash scripts/run-iothreads-benchmarks.sh
```

### Step 4: Enable IO-Threads (Round 2)

On each server, restart the Docker container with IO-threads:

```bash
# Redis 7.2 & 8.6
docker stop redis-server && docker rm redis-server
docker run -d --name redis-server --network host redis:8.6 \
  redis-server --bind 0.0.0.0 --protected-mode no --save "" --appendonly no \
  --io-threads 6 --io-threads-do-reads yes

# Valkey 9.1
docker stop valkey-server && docker rm valkey-server
docker run -d --name valkey-server --network host valkey/valkey:9.1.0-rc1 \
  valkey-server --bind 0.0.0.0 --protected-mode no --save "" --appendonly no \
  --io-threads 6 --io-threads-do-reads yes
```

## Test Matrix

| Test | Connections | Pipeline | Duration | Workload |
|------|------------|----------|----------|----------|
| Sanity Check | 1 | 1 | 10s | 80:20 GET:SET |
| High Throughput | 32 | 64 | 60s | 80:20 GET:SET |
| GET-Only | 16 | 32 | 60s | 100:0 (prefilled) |
| Write-Heavy | 16 | 32 | 60s | 20:80 GET:SET |
| Balanced | 16 | 32 | 60s | 80:20 GET:SET |
| Saturation Search | 16 | 32 | 60s | p99.9 ≤ 1ms SLO |

## Detailed Results

See the [full benchmark report](BENCHMARK-REPORT.md) for detailed per-test breakdowns with latency percentiles (p50, p99, p99.9, p99.99).

## License

MIT
