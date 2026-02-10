#!/bin/bash
# start_timer.sh - ベンチマーク開始時刻を記録
# Usage: bash benchmark/metrics/start_timer.sh <run_dir>

set -euo pipefail

RUN_DIR="${1:?Usage: $0 <run_dir>}"
mkdir -p "$RUN_DIR"

date +%s > "$RUN_DIR/start_time.txt"
echo "Timer started: $(date '+%Y-%m-%dT%H:%M:%S')"
