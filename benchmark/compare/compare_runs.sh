#!/bin/bash
# compare_runs.sh - 2つのベンチマークRunを比較
# Usage: bash benchmark/compare/compare_runs.sh <run_a_dir> <run_b_dir>

set -euo pipefail

RUN_A="${1:?Usage: $0 <run_a_dir> <run_b_dir>}"
RUN_B="${2:?Usage: $0 <run_a_dir> <run_b_dir>}"

for dir in "$RUN_A" "$RUN_B"; do
    if [ ! -f "$dir/scoring_result.json" ]; then
        echo "ERROR: $dir/scoring_result.json not found. Run scoring first."
        exit 1
    fi
done

# Python で比較レポート生成
export BENCH_RUN_A="$RUN_A"
export BENCH_RUN_B="$RUN_B"
python3 << 'PYEOF'
import json, sys, os

run_a_dir = os.environ['BENCH_RUN_A']
run_b_dir = os.environ['BENCH_RUN_B']

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

score_a = load_json(os.path.join(run_a_dir, "scoring_result.json"))
score_b = load_json(os.path.join(run_b_dir, "scoring_result.json"))
metrics_a = load_json(os.path.join(run_a_dir, "process_metrics.json"))
metrics_b = load_json(os.path.join(run_b_dir, "process_metrics.json"))
timer_a = load_json(os.path.join(run_a_dir, "timer.json"))
timer_b = load_json(os.path.join(run_b_dir, "timer.json"))

name_a = score_a.get("run_id", os.path.basename(run_a_dir))
name_b = score_b.get("run_id", os.path.basename(run_b_dir))

def delta_str(a, b):
    d = a - b
    if d > 0:
        return f"+{d}"
    return str(d)

def get_nested(d, *keys, default=0):
    for k in keys:
        if isinstance(d, dict):
            d = d.get(k, default)
        else:
            return default
    return d

# スコア
total_a = score_a.get("total_score", 0)
total_b = score_b.get("total_score", 0)
func_a = get_nested(score_a, "categories", "functional", "score")
func_b = get_nested(score_b, "categories", "functional", "score")
edge_a = get_nested(score_a, "categories", "edge_cases", "score")
edge_b = get_nested(score_b, "categories", "edge_cases", "score")
qual_a = get_nested(score_a, "categories", "code_quality", "score")
qual_b = get_nested(score_b, "categories", "code_quality", "score")

# プロセス
dur_a = timer_a.get("duration_seconds", 0)
dur_b = timer_b.get("duration_seconds", 0)
tasks_a = get_nested(metrics_a, "task_decomposition", "subtasks_created")
tasks_b = get_nested(metrics_b, "task_decomposition", "subtasks_created")
rework_a = get_nested(metrics_a, "task_decomposition", "subtasks_failed")
rework_b = get_nested(metrics_b, "task_decomposition", "subtasks_failed")
gunshi_rev_a = get_nested(metrics_a, "gunshi_review", "reviews_completed")
gunshi_rev_b = get_nested(metrics_b, "gunshi_review", "reviews_completed")
findings_a = get_nested(metrics_a, "gunshi_review", "findings_count")
findings_b = get_nested(metrics_b, "gunshi_review", "findings_count")
yaml_a = get_nested(metrics_a, "communication", "total_yaml_files")
yaml_b = get_nested(metrics_b, "communication", "total_yaml_files")

# テスト差分
tests_a = {t["id"]: t["passed"] for t in score_a.get("tests", [])}
tests_b = {t["id"]: t["passed"] for t in score_b.get("tests", [])}
test_names = {t["id"]: t["name"] for t in score_a.get("tests", []) + score_b.get("tests", [])}
test_points = {t["id"]: t["points"] for t in score_a.get("tests", []) + score_b.get("tests", [])}

passed_in_a_not_b = [tid for tid in tests_a if tests_a.get(tid) and not tests_b.get(tid, False)]
passed_in_b_not_a = [tid for tid in tests_b if tests_b.get(tid) and not tests_a.get(tid, False)]

print("=" * 56)
print(" BENCHMARK COMPARISON REPORT")
print("=" * 56)
print()
print(f"  Run A: {name_a}")
print(f"  Run B: {name_b}")
print()

# スコア表
print("--- SCORES ---")
print(f"{'':20s} {'Run A':>8s} {'Run B':>8s} {'Delta':>8s}")
print(f"{'Total Score:':20s} {total_a:>8d} {total_b:>8d} {delta_str(total_a, total_b):>8s}")
print(f"{'  Functional:':20s} {func_a:>8d} {func_b:>8d} {delta_str(func_a, func_b):>8s}")
print(f"{'  Edge Cases:':20s} {edge_a:>8d} {edge_b:>8d} {delta_str(edge_a, edge_b):>8s}")
print(f"{'  Code Quality:':20s} {qual_a:>8d} {qual_b:>8d} {delta_str(qual_a, qual_b):>8s}")
print()

# プロセスメトリクス表
print("--- PROCESS METRICS ---")
print(f"{'':20s} {'Run A':>8s} {'Run B':>8s} {'Delta':>8s}")
print(f"{'Duration (sec):':20s} {dur_a:>8d} {dur_b:>8d} {delta_str(dur_a, dur_b):>8s}")
print(f"{'Subtasks Created:':20s} {tasks_a:>8d} {tasks_b:>8d} {delta_str(tasks_a, tasks_b):>8s}")
print(f"{'Failed Tasks:':20s} {rework_a:>8d} {rework_b:>8d} {delta_str(rework_a, rework_b):>8s}")
print(f"{'Gunshi Reviews:':20s} {gunshi_rev_a:>8d} {gunshi_rev_b:>8d} {delta_str(gunshi_rev_a, gunshi_rev_b):>8s}")
print(f"{'Gunshi Findings:':20s} {findings_a:>8d} {findings_b:>8d} {delta_str(findings_a, findings_b):>8s}")
print(f"{'YAML Files:':20s} {yaml_a:>8d} {yaml_b:>8d} {delta_str(yaml_a, yaml_b):>8s}")
print()

# テスト差分
print("--- TEST DIFFERENCES ---")
if passed_in_a_not_b:
    print("Tests PASSED in A but FAILED in B:")
    for tid in sorted(passed_in_a_not_b):
        name = test_names.get(tid, "?")
        pts = test_points.get(tid, 0)
        print(f"  {tid} {name:40s} [{pts} pts]")
else:
    print("Tests PASSED in A but FAILED in B: (none)")
print()
if passed_in_b_not_a:
    print("Tests PASSED in B but FAILED in A:")
    for tid in sorted(passed_in_b_not_a):
        name = test_names.get(tid, "?")
        pts = test_points.get(tid, 0)
        print(f"  {tid} {name:40s} [{pts} pts]")
else:
    print("Tests PASSED in B but FAILED in A: (none)")

print()
print("=" * 56)

# 比較結果をJSONでも保存
comparison = {
    "run_a": name_a,
    "run_b": name_b,
    "scores": {
        "total": {"a": total_a, "b": total_b, "delta": total_a - total_b},
        "functional": {"a": func_a, "b": func_b, "delta": func_a - func_b},
        "edge_cases": {"a": edge_a, "b": edge_b, "delta": edge_a - edge_b},
        "code_quality": {"a": qual_a, "b": qual_b, "delta": qual_a - qual_b},
    },
    "process": {
        "duration_seconds": {"a": dur_a, "b": dur_b, "delta": dur_a - dur_b},
        "subtasks": {"a": tasks_a, "b": tasks_b, "delta": tasks_a - tasks_b},
        "failed_tasks": {"a": rework_a, "b": rework_b, "delta": rework_a - rework_b},
        "gunshi_reviews": {"a": gunshi_rev_a, "b": gunshi_rev_b},
        "gunshi_findings": {"a": findings_a, "b": findings_b},
    },
    "test_diffs": {
        "passed_in_a_only": passed_in_a_not_b,
        "passed_in_b_only": passed_in_b_not_a,
    }
}

output_path = os.path.join(os.path.dirname(run_a_dir), f"comparison_{os.path.basename(run_a_dir)}_vs_{os.path.basename(run_b_dir)}.json")
with open(output_path, "w") as f:
    json.dump(comparison, f, indent=2, ensure_ascii=False)
print(f"Comparison saved: {output_path}")
PYEOF
exit_code=$?

exit $exit_code
