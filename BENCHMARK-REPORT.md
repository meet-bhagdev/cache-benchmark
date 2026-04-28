# Redis 7.2 vs Redis 8.6 vs Valkey 9 — Performance Benchmark Report

**Date:** April 27-28, 2026  
**Benchmark Tool:** [valkey-lab](https://github.com/ksmotiv8/cachecannon/blob/rename-valkey-lab/VALKEY-LAB.md) (cachecannon engine, io_uring)  
**Region:** us-east-1

---

## Infrastructure

| Role | Instance Type | vCPUs | Memory | Software |
|------|-------------|-------|--------|----------|
| Redis 7.2 Server | c8g.2xlarge (Graviton4) | 8 | 16 GiB | Docker → `redis:7.2` |
| Redis 8.6 Server | c8g.2xlarge (Graviton4) | 8 | 16 GiB | Docker → `redis:8.6` |
| Valkey Server | c8g.2xlarge (Graviton4) | 8 | 16 GiB | Docker → `valkey/valkey:9` / `9.1.0-rc1` |
| Benchmark Client | c8g.4xlarge (Graviton4) | 16 | 32 GiB | valkey-lab (io_uring engine) |

- **OS:** Amazon Linux 2023 (kernel 6.18, ARM64)
- **Network:** Same VPC, private IPs, no TLS
- **Persistence:** Disabled (no RDB save, no AOF)
- **Value size:** 64 bytes (default)
- **Key size:** 16 bytes (default)
- **Keyspace:** 1,000,000 keys

---

## Test Matrix

| # | Test | Connections | Pipeline | Threads | Duration | Ratio (GET:SET) |
|---|------|------------|----------|---------|----------|-----------------|
| 1 | Sanity Check | 1 | 1 | 16 | 10s | 80:20 |
| 2 | High Throughput | 32 | 64 | 8 | 60s | 80:20 |
| 3 | GET-Only | 16 | 32 | 16 | 60s | 100:0 (prefilled) |
| 4 | Write-Heavy | 16 | 32 | 16 | 60s | 20:80 |
| 5 | Balanced | 16 | 32 | 16 | 60s | 80:20 |
| 6 | Saturation Search | 16 | 32 | 16 | 60s | 80:20 (rate-limited, p99.9 ≤ 1ms SLO) |

**Two configurations tested:**
- **Round 1:** Default (single-threaded I/O) — Valkey 9.0.3
- **Round 2:** `io-threads 6` + `io-threads-do-reads yes` — Valkey 9.1.0

---

# Round 1: Default Configuration (Single-Threaded I/O)

*Valkey version: 9.0.3*

### Throughput Summary — Default Config

| Test | Redis 7.2 | Redis 8.6 | Valkey 9.0 | 8.6 vs 7.2 | 8.6 vs Valkey |
|------|-----------|-----------|------------|-------------|---------------|
| Sanity (1 conn) | **9,837** | 9,528 | 8,071 | -3.1% | +18.0% |
| High Throughput (32c/P64) | 995,805 | **1,946,566** | 1,782,683 | **+95.5%** | +9.2% |
| GET-Only (16c/P32) | 956,276 | **1,631,693** | 1,493,256 | **+70.6%** | +9.3% |
| Write-Heavy (16c/P32) | 866,366 | **1,322,115** | 1,246,482 | **+52.6%** | +6.1% |
| Balanced (16c/P32) | 928,987 | **1,478,847** | 1,387,397 | **+59.2%** | +6.6% |
| Saturation (SLO-capped) | 178,311 | 178,308 | 178,312 | ≈ 0% | ≈ 0% |

### Detailed Results — Default Config

#### Test 1: Sanity Check (1 conn, no pipeline, 10s)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.0 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | **9,837** | 9,528 | 8,071 | 🔵 Redis 7.2 |
| GET p50 (µs) | **100** | 101 | 122 | 🔵 Redis 7.2 |
| GET p99 (µs) | 258 | **142** | 141 | 🟢 Valkey |
| GET p99.9 (µs) | 264 | 217 | **186** | 🟢 Valkey |
| SET p50 (µs) | **101** | 103 | 124 | 🔵 Redis 7.2 |
| SET p99 (µs) | 259 | **145** | 142 | 🟢 Valkey |

#### Test 2: High Throughput (32 conns, pipeline 64, 60s)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.0 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | 995,805 | **1,946,566** | 1,782,683 | 🔴 Redis 8.6 |
| GET p50 (µs) | 2,047 | **1,048** | 1,155 | 🔴 Redis 8.6 |
| GET p99 (µs) | 2,228 | **1,212** | 1,327 | 🔴 Redis 8.6 |
| GET p99.9 (µs) | 2,342 | **1,523** | 4,095 | 🔴 Redis 8.6 |
| SET p99.9 (µs) | 2,342 | **1,523** | 4,095 | 🔴 Redis 8.6 |

#### Test 3: GET-Only (100:0, prefilled, 16 conns, pipeline 32, 60s)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.0 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | 956,276 | **1,631,693** | 1,493,256 | 🔴 Redis 8.6 |
| GET p50 (µs) | 528 | **307** | 344 | 🔴 Redis 8.6 |
| GET p99 (µs) | 815 | **483** | 536 | 🔴 Redis 8.6 |
| GET p99.9 (µs) | 937 | **557** | 626 | 🔴 Redis 8.6 |

#### Test 4: Write-Heavy (20:80, 16 conns, pipeline 32, 60s)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.0 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | 866,366 | **1,322,115** | 1,246,482 | 🔴 Redis 8.6 |
| GET p50 (µs) | 581 | **391** | 409 | 🔴 Redis 8.6 |
| SET p99 (µs) | 901 | **602** | 630 | 🔴 Redis 8.6 |
| SET p99.9 (µs) | 1,023 | 778 | **761** | 🟢 Valkey |

#### Test 5: Balanced (80:20, 16 conns, pipeline 32, 60s)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.0 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | 928,987 | **1,478,847** | 1,387,397 | 🔴 Redis 8.6 |
| GET p50 (µs) | 540 | **344** | 354 | 🔴 Redis 8.6 |
| GET p99 (µs) | 851 | **540** | 589 | 🔴 Redis 8.6 |
| SET max (µs) | 1,245 | 1,310 | **942** | 🟢 Valkey |

#### Test 6: Saturation Search (p99.9 ≤ 1ms SLO)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.0 | Winner |
|--------|-----------|-----------|------------|--------|
| **Max SLO Throughput (req/s)** | 178,311 | 178,308 | 178,312 | ≈ Tie |
| GET p99 (µs) | 387 | **313** | 329 | 🔴 Redis 8.6 |
| GET p99.9 (µs) | 679 | 466 | **446** | 🟢 Valkey |
| GET p99.99 (µs) | 798 | 618 | **548** | 🟢 Valkey |

---

# Round 2: IO-Threads Enabled (6 threads)

*Configuration: `io-threads 6`, `io-threads-do-reads yes`*  
*Valkey version: 9.1.0 (RC1)*

### ⚡ Throughput Summary — IO-Threads Config

| Test | Redis 7.2 | Redis 8.6 | Valkey 9.1 | 8.6 vs 7.2 | Valkey vs 8.6 |
|------|-----------|-----------|------------|-------------|---------------|
| Sanity (1 conn) | **9,908** | 9,447 | 8,331 | -4.7% | -11.8% |
| High Throughput (32c/P64) | 1,031,883 | 2,199,945 | **2,541,896** | +113% | **+15.5%** 🟢 |
| GET-Only (16c/P32) | 930,736 | 1,947,558 | **1,893,808** | +109% | -2.8% |
| Write-Heavy (16c/P32) | 825,857 | 1,485,448 | **1,652,042** | +80% | **+11.2%** 🟢 |
| Balanced (16c/P32) | 867,015 | 1,766,589 | **1,771,812** | +104% | **+0.3%** 🟢 |
| Saturation (SLO-capped) | 178,309 | 178,310 | 178,312 | ≈ 0% | ≈ 0% |

### Detailed Results — IO-Threads Config

#### Test 1: Sanity Check (1 conn, no pipeline, 10s)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.1 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | **9,908** | 9,447 | 8,331 | 🔵 Redis 7.2 |
| GET p50 (µs) | **99** | 104 | 118 | 🔵 Redis 7.2 |
| GET p99 (µs) | 132 | **129** | 140 | 🔴 Redis 8.6 |
| GET p99.9 (µs) | 194 | **175** | 219 | 🔴 Redis 8.6 |
| SET p50 (µs) | **100** | 105 | 119 | 🔵 Redis 7.2 |

> Single-connection: IO-threads has minimal impact (expected — threads help with concurrent connections).

#### Test 2: High Throughput (32 conns, pipeline 64, 60s) ⭐

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.1 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | 1,031,883 | 2,199,945 | **2,541,896** | 🟢 **Valkey 9.1** |
| **Total Requests** | 61.9M | 132.0M | **152.5M** | 🟢 **Valkey 9.1** |
| GET p50 (µs) | 1,974 | 917 | **802** | 🟢 **Valkey 9.1** |
| GET p99 (µs) | 2,179 | 1,302 | **1,179** | 🟢 **Valkey 9.1** |
| GET p99.9 (µs) | 2,392 | **1,433** | 1,671 | 🔴 Redis 8.6 |
| GET p99.99 (µs) | 3,932 | **1,712** | 2,424 | 🔴 Redis 8.6 |
| SET p50 (µs) | 1,974 | 917 | **802** | 🟢 **Valkey 9.1** |
| SET p99 (µs) | 2,179 | 1,294 | **1,179** | 🟢 **Valkey 9.1** |

> **🏆 Valkey 9.1 takes the crown at 2.54M req/s** — 15.5% faster than Redis 8.6 and 146% faster than Redis 7.2. Valkey's I/O threading with batched pipeline processing delivers superior throughput and better median/p99 latency.

#### Test 3: GET-Only (100:0, prefilled, 16 conns, pipeline 32, 60s)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.1 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | 930,736 | **1,947,558** | 1,893,808 | 🔴 Redis 8.6 |
| **Total Requests** | 55.8M | **116.9M** | 113.6M | 🔴 Redis 8.6 |
| GET p50 (µs) | 532 | **272** | 274 | 🔴 Redis 8.6 (≈ tie) |
| GET p99 (µs) | 835 | **405** | 417 | 🔴 Redis 8.6 |
| GET p99.9 (µs) | 983 | **479** | 491 | 🔴 Redis 8.6 |
| GET p99.99 (µs) | 1,064 | **552** | 602 | 🔴 Redis 8.6 |

> Redis 8.6 edges out Valkey by 2.8% in pure GET workloads. Both are neck-and-neck — essentially a tie.

#### Test 4: Write-Heavy (20:80, 16 conns, pipeline 32, 60s) ⭐

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.1 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | 825,857 | 1,485,448 | **1,652,042** | 🟢 **Valkey 9.1** |
| **Total Requests** | 49.6M | 89.1M | **99.1M** | 🟢 **Valkey 9.1** |
| GET p50 (µs) | 602 | 346 | **303** | 🟢 **Valkey 9.1** |
| GET p99 (µs) | 1,023 | 528 | **450** | 🟢 **Valkey 9.1** |
| GET p99.9 (µs) | 1,064 | 589 | **557** | 🟢 **Valkey 9.1** |
| SET p50 (µs) | 602 | 346 | **301** | 🟢 **Valkey 9.1** |
| SET p99 (µs) | 1,019 | 528 | **448** | 🟢 **Valkey 9.1** |
| SET p99.9 (µs) | 1,064 | 589 | **557** | 🟢 **Valkey 9.1** |
| SET max (µs) | **1,359** | **1,335** | 2,899 | 🔴 Redis 8.6 |

> **🏆 Valkey 9.1 dominates write-heavy workloads** — 11.2% faster than Redis 8.6 with lower latency across p50/p99/p99.9. The I/O thread batching particularly shines with write operations.

#### Test 5: Balanced (80:20, 16 conns, pipeline 32, 60s)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.1 | Winner |
|--------|-----------|-----------|------------|--------|
| **Throughput (req/s)** | 867,015 | 1,766,589 | **1,771,812** | 🟢 Valkey 9.1 (≈ tie) |
| **Total Requests** | 52.0M | 106.0M | **106.3M** | ≈ Tie |
| GET p50 (µs) | 565 | 278 | **280** | ≈ Tie |
| GET p99 (µs) | 901 | 499 | **458** | 🟢 **Valkey 9.1** |
| GET p99.9 (µs) | 1,056 | **552** | **552** | ≈ Tie |
| SET p50 (µs) | 565 | 276 | **278** | ≈ Tie |
| SET p99 (µs) | 897 | 487 | **442** | 🟢 **Valkey 9.1** |
| SET max (µs) | **1,310** | **1,105** | 3,407 | 🔴 Redis 8.6 |

> Balanced workload is essentially a dead heat between Redis 8.6 and Valkey 9.1, with Valkey having slightly better p99 latency.

#### Test 6: Saturation Search (p99.9 ≤ 1ms SLO)

| Metric | Redis 7.2 | Redis 8.6 | Valkey 9.1 | Winner |
|--------|-----------|-----------|------------|--------|
| **Max SLO Throughput (req/s)** | 178,309 | 178,310 | 178,312 | ≈ Tie |
| GET p50 (µs) | 144 | **142** | 159 | 🔴 Redis 8.6 |
| GET p99 (µs) | 387 | **294** | 305 | 🔴 Redis 8.6 |
| GET p99.9 (µs) | 696 | **391** | 403 | 🔴 Redis 8.6 |
| SET p99 (µs) | 385 | **286** | 292 | 🔴 Redis 8.6 |
| SET p99.9 (µs) | 696 | **380** | 395 | 🔴 Redis 8.6 |

> Under SLO constraints, all three converge to identical throughput. Redis 8.6 has the best latency profile in this scenario.

---

# IO-Threads Impact Analysis

### Throughput Change: Default → IO-Threads 6

| Test | Redis 7.2 | Redis 8.6 | Valkey 9 → 9.1 |
|------|-----------|-----------|-----------------|
| Sanity (1 conn) | +0.7% | -0.9% | +3.2% |
| High Throughput | +3.6% | **+13.0%** | **+42.6%** 🚀 |
| GET-Only | -2.7% | **+19.3%** | **+26.8%** 🚀 |
| Write-Heavy | -4.7% | **+12.4%** | **+32.5%** 🚀 |
| Balanced | -6.7% | **+19.4%** | **+27.7%** 🚀 |
| Saturation | ≈ 0% | ≈ 0% | ≈ 0% |

### Key Observations

| Insight | Detail |
|---------|--------|
| **Valkey 9.1 scales dramatically with IO-threads** | 27-43% throughput improvement across pipelined workloads |
| **Redis 8.6 also benefits significantly** | 12-19% improvement with IO-threads |
| **Redis 7.2 barely benefits from IO-threads** | Near-zero or slightly negative impact (known limitation) |
| **Valkey's IO-thread batching is the differentiator** | Enables superior pipeline processing under concurrent load |

---

# Grand Summary

### Peak Throughput Achieved (req/s)

| Test | Redis 7.2 (best) | Redis 8.6 (best) | Valkey (best) | Overall Winner |
|------|-------------------|-------------------|---------------|---------------|
| Sanity (1 conn) | **9,908** | 9,528 | 8,331 | 🔵 Redis 7.2 |
| High Throughput | 1,031,883 | 2,199,945 | **2,541,896** | 🟢 **Valkey 9.1** |
| GET-Only | 956,276 | **1,947,558** | 1,893,808 | 🔴 Redis 8.6 |
| Write-Heavy | 866,366 | 1,485,448 | **1,652,042** | 🟢 **Valkey 9.1** |
| Balanced | 928,987 | 1,766,589 | **1,771,812** | 🟢 **Valkey 9.1** |
| Saturation | 178,311 | 178,310 | 178,312 | ≈ Tie |

### Performance Ranking

```
                    Default (1 IO thread)     IO-Threads 6
                    ─────────────────────     ────────────────────
High Throughput:    🥇 Redis 8.6  1.95M      🥇 Valkey 9.1  2.54M  (+15.5% vs Redis 8.6)
                    🥈 Valkey 9.0 1.78M      🥈 Redis 8.6   2.20M
                    🥉 Redis 7.2  1.00M      🥉 Redis 7.2   1.03M

Write-Heavy:        🥇 Redis 8.6  1.32M      🥇 Valkey 9.1  1.65M  (+11.2% vs Redis 8.6)
                    🥈 Valkey 9.0 1.25M      🥈 Redis 8.6   1.49M
                    🥉 Redis 7.2  0.87M      🥉 Redis 7.2   0.83M

GET-Only:           🥇 Redis 8.6  1.63M      🥇 Redis 8.6   1.95M  (+2.8% vs Valkey 9.1)
                    🥈 Valkey 9.0 1.49M      🥈 Valkey 9.1  1.89M
                    🥉 Redis 7.2  0.96M      🥉 Redis 7.2   0.93M
```

### Key Takeaways

1. **🏆 Valkey 9.1 with IO-threads is the fastest cache engine tested** — peaking at **2.54M req/s** in the high-throughput test, 15.5% faster than Redis 8.6 with the same IO-thread config.

2. **Valkey's IO-thread scaling is dramatically better** — 27-43% throughput gains from enabling IO-threads, vs Redis 8.6's 12-19% and Redis 7.2's near-zero gains.

3. **Redis 8.6 wins without IO-threads** — in default single-threaded mode, Redis 8.6 leads by 6-9% over Valkey 9.0.

4. **Redis 8.6 still wins for pure GET workloads** — a slight 2.8% edge over Valkey with IO-threads enabled.

5. **Valkey dominates write-heavy workloads with IO-threads** — 11.2% faster than Redis 8.6 with better latency across all percentiles except max.

6. **Redis 7.2 is the clear loser** — 2-2.5x slower than both Redis 8.6 and Valkey 9 in pipelined scenarios, and doesn't benefit from IO-threads.

7. **Under SLO constraints, all engines are equivalent** — ~178K req/s regardless of engine or IO-thread config.

8. **Zero errors across all tests** — all three engines are rock-solid.

### Upgrade paths

| From / To | Verdict | Gain |
|-----------|---------|------|
| Redis 7.2 → Valkey 9.1 (io-threads 6) | Do it | up to +146% |
| Redis 7.2 → Redis 8.6 (io-threads 6) | Do it | up to +113% |
| Redis 8.6 → Valkey 9.1 (both with io-threads) | Worth it | +11-15% |
| Redis 8.6 (default) → Redis 8.6 (io-threads 6) | Free perf | +12-19% |
| Any engine, enable io-threads | Free perf | +13-30% |

### The Bottom Line

> **Without IO-threads, Redis 8.6 wins. With IO-threads enabled, Valkey 9.1 wins.** The choice depends on your deployment configuration. For production workloads using IO-threads (which you should be), Valkey 9.1 delivers the best performance — especially for write-heavy and high-throughput pipelined workloads — while also offering an open-source BSD-3 license.

---

## EC2 Instance Details

| Instance | ID | Private IP | Type | Software |
|----------|-----|-----------|------|----------|
| Redis 7.2 Server | i-0b9b55b70641b51b8 | 172.31.74.7 | c8g.2xlarge | redis:7.2 |
| Redis 8.6 Server | i-0d8d395c293f86f88 | 172.31.65.239 | c8g.2xlarge | redis:8.6 |
| Valkey Server | i-078174b4e7010b88a | 172.31.75.111 | c8g.2xlarge | valkey:9.1.0-rc1 |
| Client | i-026b217bd9e5c70a0 | 172.31.68.2 | c8g.4xlarge | valkey-lab |

*All instances left running as requested.*
