#!/bin/bash
set -e

REDIS72_IP="172.31.74.7"
RESULTS_DIR="/home/ec2-user/bench-results"
mkdir -p "$RESULTS_DIR"

echo "Starting Redis 7.2 benchmarks at $(date)" > "$RESULTS_DIR/redis72_benchmark.log"

echo "=== Test 1: Sanity Check ===" >> "$RESULTS_DIR/redis72_benchmark.log"
valkey-lab -h "$REDIS72_IP" -d 10s -o json > "$RESULTS_DIR/redis72_test1_sanity.json" 2>&1
echo "Test 1 done at $(date)" >> "$RESULTS_DIR/redis72_benchmark.log"

echo "=== Test 2: High Throughput ===" >> "$RESULTS_DIR/redis72_benchmark.log"
valkey-lab -h "$REDIS72_IP" -c 32 -P 64 -t 8 -d 60s -o json > "$RESULTS_DIR/redis72_test2_high_throughput.json" 2>&1
echo "Test 2 done at $(date)" >> "$RESULTS_DIR/redis72_benchmark.log"

echo "=== Test 3: GET-Only ===" >> "$RESULTS_DIR/redis72_benchmark.log"
valkey-lab -h "$REDIS72_IP" -r 100:0 -c 16 -P 32 -d 60s --prefill -o json > "$RESULTS_DIR/redis72_test3_get_only.json" 2>&1
echo "Test 3 done at $(date)" >> "$RESULTS_DIR/redis72_benchmark.log"

echo "=== Test 4: Write-Heavy ===" >> "$RESULTS_DIR/redis72_benchmark.log"
valkey-lab -h "$REDIS72_IP" -r 20:80 -c 16 -P 32 -d 60s -o json > "$RESULTS_DIR/redis72_test4_write_heavy.json" 2>&1
echo "Test 4 done at $(date)" >> "$RESULTS_DIR/redis72_benchmark.log"

echo "=== Test 5: Balanced 80:20 ===" >> "$RESULTS_DIR/redis72_benchmark.log"
valkey-lab -h "$REDIS72_IP" -r 80:20 -c 16 -P 32 -d 60s -o json > "$RESULTS_DIR/redis72_test5_balanced.json" 2>&1
echo "Test 5 done at $(date)" >> "$RESULTS_DIR/redis72_benchmark.log"

echo "=== Test 6: Saturation Search ===" >> "$RESULTS_DIR/redis72_benchmark.log"
valkey-lab saturate -h "$REDIS72_IP" --slo-p999 1ms --start-rate 100000 --step 1.1 -c 16 -P 32 -o json > "$RESULTS_DIR/redis72_test6_saturate.json" 2>&1
echo "Test 6 done at $(date)" >> "$RESULTS_DIR/redis72_benchmark.log"

echo "ALL_REDIS72_BENCHMARKS_COMPLETE at $(date)" >> "$RESULTS_DIR/redis72_benchmark.log"
echo "REDIS72_BENCHMARKS_DONE" > /tmp/redis72-bench-status
