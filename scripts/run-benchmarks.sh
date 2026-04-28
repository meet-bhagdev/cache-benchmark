#!/bin/bash
set -e

REDIS_IP="172.31.65.239"
VALKEY_IP="172.31.75.111"
RESULTS_DIR="/home/ec2-user/bench-results"
mkdir -p "$RESULTS_DIR"

echo "Starting benchmarks at $(date)" > "$RESULTS_DIR/benchmark.log"

# Test 1: Quick sanity check (10s, defaults)
echo "=== Test 1: Sanity Check ===" >> "$RESULTS_DIR/benchmark.log"
valkey-lab -h "$REDIS_IP" -d 10s -o json > "$RESULTS_DIR/redis_test1_sanity.json" 2>&1
valkey-lab -h "$VALKEY_IP" -d 10s -o json > "$RESULTS_DIR/valkey_test1_sanity.json" 2>&1
echo "Test 1 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

# Test 2: High-throughput (32 conns, pipeline 64, 8 threads, 60s)
echo "=== Test 2: High Throughput ===" >> "$RESULTS_DIR/benchmark.log"
valkey-lab -h "$REDIS_IP" -c 32 -P 64 -t 8 -d 60s -o json > "$RESULTS_DIR/redis_test2_high_throughput.json" 2>&1
valkey-lab -h "$VALKEY_IP" -c 32 -P 64 -t 8 -d 60s -o json > "$RESULTS_DIR/valkey_test2_high_throughput.json" 2>&1
echo "Test 2 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

# Test 3: GET-only workload (100:0 ratio, 16 conns, pipeline 32, 60s)
echo "=== Test 3: GET-Only ===" >> "$RESULTS_DIR/benchmark.log"
valkey-lab -h "$REDIS_IP" -r 100:0 -c 16 -P 32 -d 60s --prefill -o json > "$RESULTS_DIR/redis_test3_get_only.json" 2>&1
valkey-lab -h "$VALKEY_IP" -r 100:0 -c 16 -P 32 -d 60s --prefill -o json > "$RESULTS_DIR/valkey_test3_get_only.json" 2>&1
echo "Test 3 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

# Test 4: Write-heavy workload (20:80 ratio, 16 conns, pipeline 32, 60s)
echo "=== Test 4: Write-Heavy ===" >> "$RESULTS_DIR/benchmark.log"
valkey-lab -h "$REDIS_IP" -r 20:80 -c 16 -P 32 -d 60s -o json > "$RESULTS_DIR/redis_test4_write_heavy.json" 2>&1
valkey-lab -h "$VALKEY_IP" -r 20:80 -c 16 -P 32 -d 60s -o json > "$RESULTS_DIR/valkey_test4_write_heavy.json" 2>&1
echo "Test 4 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

# Test 5: Balanced workload (default 80:20, 16 conns, pipeline 32, 60s)
echo "=== Test 5: Balanced 80:20 ===" >> "$RESULTS_DIR/benchmark.log"
valkey-lab -h "$REDIS_IP" -r 80:20 -c 16 -P 32 -d 60s -o json > "$RESULTS_DIR/redis_test5_balanced.json" 2>&1
valkey-lab -h "$VALKEY_IP" -r 80:20 -c 16 -P 32 -d 60s -o json > "$RESULTS_DIR/valkey_test5_balanced.json" 2>&1
echo "Test 5 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

# Test 6: Saturation search (find max throughput under p99.9 < 1ms SLO)
echo "=== Test 6: Saturation Search ===" >> "$RESULTS_DIR/benchmark.log"
valkey-lab saturate -h "$REDIS_IP" --slo-p999 1ms --start-rate 100000 --step 1.1 -c 16 -P 32 -o json > "$RESULTS_DIR/redis_test6_saturate.json" 2>&1
valkey-lab saturate -h "$VALKEY_IP" --slo-p999 1ms --start-rate 100000 --step 1.1 -c 16 -P 32 -o json > "$RESULTS_DIR/valkey_test6_saturate.json" 2>&1
echo "Test 6 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

echo "ALL_BENCHMARKS_COMPLETE at $(date)" >> "$RESULTS_DIR/benchmark.log"
echo "BENCHMARKS_DONE" > /tmp/bench-status
