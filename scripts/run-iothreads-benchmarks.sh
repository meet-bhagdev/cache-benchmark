#!/bin/bash
set -e

REDIS72_IP="172.31.74.7"
REDIS86_IP="172.31.65.239"
VALKEY_IP="172.31.75.111"
RESULTS_DIR="/home/ec2-user/bench-results-iothreads"
mkdir -p "$RESULTS_DIR"

echo "Starting io-threads benchmarks at $(date)" > "$RESULTS_DIR/benchmark.log"

for SERVER_NAME in redis72 redis86 valkey9; do
  case $SERVER_NAME in
    redis72) IP=$REDIS72_IP ;;
    redis86) IP=$REDIS86_IP ;;
    valkey9) IP=$VALKEY_IP ;;
  esac

  echo "=== $SERVER_NAME Test 1: Sanity Check ===" >> "$RESULTS_DIR/benchmark.log"
  valkey-lab -h "$IP" -d 10s -o json > "$RESULTS_DIR/${SERVER_NAME}_test1_sanity.json" 2>&1
  echo "$SERVER_NAME Test 1 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

  echo "=== $SERVER_NAME Test 2: High Throughput ===" >> "$RESULTS_DIR/benchmark.log"
  valkey-lab -h "$IP" -c 32 -P 64 -t 8 -d 60s -o json > "$RESULTS_DIR/${SERVER_NAME}_test2_high_throughput.json" 2>&1
  echo "$SERVER_NAME Test 2 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

  echo "=== $SERVER_NAME Test 3: GET-Only ===" >> "$RESULTS_DIR/benchmark.log"
  valkey-lab -h "$IP" -r 100:0 -c 16 -P 32 -d 60s --prefill -o json > "$RESULTS_DIR/${SERVER_NAME}_test3_get_only.json" 2>&1
  echo "$SERVER_NAME Test 3 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

  echo "=== $SERVER_NAME Test 4: Write-Heavy ===" >> "$RESULTS_DIR/benchmark.log"
  valkey-lab -h "$IP" -r 20:80 -c 16 -P 32 -d 60s -o json > "$RESULTS_DIR/${SERVER_NAME}_test4_write_heavy.json" 2>&1
  echo "$SERVER_NAME Test 4 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

  echo "=== $SERVER_NAME Test 5: Balanced 80:20 ===" >> "$RESULTS_DIR/benchmark.log"
  valkey-lab -h "$IP" -r 80:20 -c 16 -P 32 -d 60s -o json > "$RESULTS_DIR/${SERVER_NAME}_test5_balanced.json" 2>&1
  echo "$SERVER_NAME Test 5 done at $(date)" >> "$RESULTS_DIR/benchmark.log"

  echo "=== $SERVER_NAME Test 6: Saturation Search ===" >> "$RESULTS_DIR/benchmark.log"
  valkey-lab saturate -h "$IP" --slo-p999 1ms --start-rate 100000 --step 1.1 -c 16 -P 32 -o json > "$RESULTS_DIR/${SERVER_NAME}_test6_saturate.json" 2>&1
  echo "$SERVER_NAME Test 6 done at $(date)" >> "$RESULTS_DIR/benchmark.log"
done

echo "ALL_IOTHREADS_BENCHMARKS_COMPLETE at $(date)" >> "$RESULTS_DIR/benchmark.log"
echo "IOTHREADS_DONE" > /tmp/iothreads-bench-status
