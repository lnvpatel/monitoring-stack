# Node Exporter

Node Exporter is a Prometheus exporter for Linux hardware and OS metrics.
It is deployed as a Docker container alongside Prometheus and Grafana.

## What it collects

| Collector | Metrics |
|---|---|
| `cpu` | Per-CPU usage, modes (user/system/idle/iowait) |
| `meminfo` | RAM total/free/available, swap, cached, buffers |
| `filesystem` | Disk usage, inodes per mountpoint |
| `diskstats` | I/O reads/writes, latency per device |
| `netdev` | Bytes/packets TX/RX, errors per interface |
| `loadavg` | 1/5/15 minute load averages |
| `uname` | Kernel version, hostname, architecture |
| `stat` | Context switches, forks, interrupts |
| `processes` | Running, blocked processes |
| `systemd` | Service state (active/failed/inactive) |

## Metrics endpoint

```
http://localhost:9100/metrics
```

## Running standalone (without Docker Compose)

```bash
# Pull and run
docker run -d \
  --name node-exporter \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  prom/node-exporter:latest \
  --path.rootfs=/host

# Verify
curl http://localhost:9100/metrics | head -20
```

## Key PromQL queries

```promql
# CPU usage %
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage %
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage % for root
(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100

# Network receive rate
rate(node_network_receive_bytes_total{device!="lo"}[5m])

# Load average
node_load1
```
