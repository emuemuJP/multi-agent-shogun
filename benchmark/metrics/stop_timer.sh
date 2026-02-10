#!/bin/bash
# stop_timer.sh - ベンチマーク終了時刻を記録し所要時間を計算
# Usage: bash benchmark/metrics/stop_timer.sh <run_dir>

set -euo pipefail

RUN_DIR="${1:?Usage: $0 <run_dir>}"
START_FILE="$RUN_DIR/start_time.txt"

if [ ! -f "$START_FILE" ]; then
    echo "ERROR: start_time.txt not found. Did you run start_timer.sh?"
    exit 1
fi

START_EPOCH=$(cat "$START_FILE")
END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo "$END_EPOCH" > "$RUN_DIR/end_time.txt"

cat > "$RUN_DIR/timer.json" <<JSONEOF
{
  "start_epoch": $START_EPOCH,
  "end_epoch": $END_EPOCH,
  "duration_seconds": $DURATION,
  "duration_human": "${MINUTES}m ${SECONDS}s"
}
JSONEOF

echo "Timer stopped: $(date '+%Y-%m-%dT%H:%M:%S')"
echo "Duration: ${MINUTES}m ${SECONDS}s ($DURATION seconds)"
