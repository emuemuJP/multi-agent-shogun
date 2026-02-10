#!/bin/bash
# collect_process_metrics.sh - プロセスメトリクス収集
# Usage: bash benchmark/metrics/collect_process_metrics.sh <run_dir>

set -euo pipefail

RUN_DIR="${1:?Usage: $0 <run_dir>}"
SNAPSHOT="$RUN_DIR/queue_snapshot"
OUTPUT="$RUN_DIR/process_metrics.json"

# --- 通信メトリクス ---

# 将軍→家老コマンド数
shogun_commands=0
if [ -f "$SNAPSHOT/shogun_to_karo.yaml" ]; then
    shogun_commands=$(grep -c "id: cmd_" "$SNAPSHOT/shogun_to_karo.yaml" 2>/dev/null || echo 0)
fi

# 家老→足軽タスク数
ashigaru_tasks=0
if [ -d "$SNAPSHOT/tasks" ]; then
    for f in "$SNAPSHOT/tasks"/ashigaru*.yaml; do
        [ -f "$f" ] || continue
        if grep -q "task_id:\|status:" "$f" 2>/dev/null; then
            ashigaru_tasks=$((ashigaru_tasks + 1))
        fi
    done
fi

# 家老→軍師レビュー依頼数
karo_to_gunshi=0
if [ -f "$SNAPSHOT/karo_to_gunshi.yaml" ]; then
    karo_to_gunshi=$(grep -c "review_type:\|request_from:" "$SNAPSHOT/karo_to_gunshi.yaml" 2>/dev/null || echo 0)
    [ "$karo_to_gunshi" -gt 0 ] && karo_to_gunshi=1  # 1ファイル=1リクエスト
fi

# 将軍→軍師相談数
shogun_to_gunshi=0
if [ -f "$SNAPSHOT/shogun_to_gunshi.yaml" ]; then
    shogun_to_gunshi=$(grep -c "type:\|question:" "$SNAPSHOT/shogun_to_gunshi.yaml" 2>/dev/null || echo 0)
    [ "$shogun_to_gunshi" -gt 0 ] && shogun_to_gunshi=1
fi

# 足軽レポート数
ashigaru_reports=0
reports_done=0
reports_failed=0
if [ -d "$SNAPSHOT/reports" ]; then
    for f in "$SNAPSHOT/reports"/ashigaru*_report.yaml; do
        [ -f "$f" ] || continue
        if grep -q "status:" "$f" 2>/dev/null; then
            ashigaru_reports=$((ashigaru_reports + 1))
            if grep -q "status: done" "$f" 2>/dev/null; then
                reports_done=$((reports_done + 1))
            elif grep -q "status: failed" "$f" 2>/dev/null; then
                reports_failed=$((reports_failed + 1))
            fi
        fi
    done
fi

# 軍師レビュー数
gunshi_reviews=0
gunshi_verdict=""
gunshi_findings=0
gunshi_critical=0
gunshi_major=0
gunshi_minor=0
gunshi_info=0
if [ -f "$SNAPSHOT/reports/gunshi_review.yaml" ]; then
    if grep -q "verdict:" "$SNAPSHOT/reports/gunshi_review.yaml" 2>/dev/null; then
        gunshi_reviews=1
        gunshi_verdict=$(grep "verdict:" "$SNAPSHOT/reports/gunshi_review.yaml" | head -1 | awk '{print $2}')
        gunshi_findings=$(grep -c "id: R" "$SNAPSHOT/reports/gunshi_review.yaml" 2>/dev/null || echo 0)
        gunshi_critical=$(grep -c "severity: critical" "$SNAPSHOT/reports/gunshi_review.yaml" 2>/dev/null || echo 0)
        gunshi_major=$(grep -c "severity: major" "$SNAPSHOT/reports/gunshi_review.yaml" 2>/dev/null || echo 0)
        gunshi_minor=$(grep -c "severity: minor" "$SNAPSHOT/reports/gunshi_review.yaml" 2>/dev/null || echo 0)
        gunshi_info=$(grep -c "severity: info" "$SNAPSHOT/reports/gunshi_review.yaml" 2>/dev/null || echo 0)
    fi
fi

# YAML合計ファイル数
total_yaml=0
if [ -d "$SNAPSHOT" ]; then
    total_yaml=$(find "$SNAPSHOT" -name "*.yaml" -type f | wc -l | tr -d ' ')
fi

# --- タスク分解メトリクス ---
subtasks_completed=$reports_done
subtasks_failed=$reports_failed
subtasks_blocked=0
if [ -d "$SNAPSHOT/reports" ]; then
    for f in "$SNAPSHOT/reports"/ashigaru*_report.yaml; do
        [ -f "$f" ] || continue
        if grep -q "status: blocked" "$f" 2>/dev/null; then
            subtasks_blocked=$((subtasks_blocked + 1))
        fi
    done
fi

# 足軽使用率（どのpaneが使われたか）
ashigaru_utilization="["
for i in $(seq 1 8); do
    if [ -f "$SNAPSHOT/tasks/ashigaru${i}.yaml" ] && grep -q "task_id:" "$SNAPSHOT/tasks/ashigaru${i}.yaml" 2>/dev/null; then
        ashigaru_utilization+="1"
    else
        ashigaru_utilization+="0"
    fi
    [ $i -lt 8 ] && ashigaru_utilization+=","
done
ashigaru_utilization+="]"

# スキル化候補
skill_candidates=0
if [ -d "$SNAPSHOT/reports" ]; then
    for f in "$SNAPSHOT/reports"/ashigaru*_report.yaml; do
        [ -f "$f" ] || continue
        if grep -q "found: true" "$f" 2>/dev/null; then
            skill_candidates=$((skill_candidates + 1))
        fi
    done
fi

# --- タイマー情報の読み込み ---
duration_seconds=0
if [ -f "$RUN_DIR/timer.json" ]; then
    duration_seconds=$(python3 -c "import json; print(json.load(open('$RUN_DIR/timer.json'))['duration_seconds'])" 2>/dev/null || echo 0)
fi

# --- JSON出力 ---
cat > "$OUTPUT" <<JSONEOF
{
  "run_id": "$(basename "$RUN_DIR")",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": $duration_seconds,
  "communication": {
    "shogun_to_karo_commands": $shogun_commands,
    "karo_to_ashigaru_tasks": $ashigaru_tasks,
    "karo_to_gunshi_reviews": $karo_to_gunshi,
    "shogun_to_gunshi_consultations": $shogun_to_gunshi,
    "ashigaru_reports": $ashigaru_reports,
    "gunshi_reviews": $gunshi_reviews,
    "total_yaml_files": $total_yaml
  },
  "task_decomposition": {
    "subtasks_created": $ashigaru_tasks,
    "subtasks_completed": $subtasks_completed,
    "subtasks_failed": $subtasks_failed,
    "subtasks_blocked": $subtasks_blocked,
    "ashigaru_utilization": $ashigaru_utilization,
    "skill_candidates_found": $skill_candidates
  },
  "gunshi_review": {
    "reviews_requested": $karo_to_gunshi,
    "reviews_completed": $gunshi_reviews,
    "verdict": "$gunshi_verdict",
    "findings_count": $gunshi_findings,
    "findings_by_severity": {
      "critical": $gunshi_critical,
      "major": $gunshi_major,
      "minor": $gunshi_minor,
      "info": $gunshi_info
    }
  }
}
JSONEOF

echo "Process metrics collected: $OUTPUT"
