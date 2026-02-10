#!/bin/bash
# run_tests.sh - ベンチマーク自動テストランナー
# Usage: bash benchmark/scoring/run_tests.sh <run_dir>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="${1:?Usage: $0 <run_dir>}"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"

# gradecalc.py を探す
GRADECALC=""
if [ -f "$RUN_DIR/output/gradecalc.py" ]; then
    GRADECALC="$RUN_DIR/output/gradecalc.py"
elif [ -f "$RUN_DIR/output/gradecalc/gradecalc.py" ]; then
    GRADECALC="$RUN_DIR/output/gradecalc/gradecalc.py"
elif [ -f "$RUN_DIR/output/gradecalc/__main__.py" ]; then
    GRADECALC="$RUN_DIR/output/gradecalc/__main__.py"
else
    echo "ERROR: gradecalc.py not found in $RUN_DIR/output/"
    echo '{"error": "gradecalc.py not found", "total_score": 0, "max_score": 100}' > "$RUN_DIR/scoring_result.json"
    exit 1
fi

export GRADECALC
export TEST_LOG="$RUN_DIR/test_log.txt"
echo "=== Benchmark Test Run: $(date) ===" > "$TEST_LOG"
echo "Target: $GRADECALC" >> "$TEST_LOG"

# Python構文チェック
if ! python3 -c "import py_compile; py_compile.compile('$GRADECALC', doraise=True)" >> "$TEST_LOG" 2>&1; then
    echo "ERROR: Python syntax error in $GRADECALC"
    echo '{"error": "syntax_error", "total_score": 0, "max_score": 100}' > "$RUN_DIR/scoring_result.json"
    exit 1
fi

# テスト結果格納
declare -a RESULTS_ID=()
declare -a RESULTS_NAME=()
declare -a RESULTS_POINTS=()
declare -a RESULTS_PASSED=()
declare -a RESULTS_REASON=()

TOTAL_SCORE=0
FUNC_SCORE=0
FUNC_PASSED=0
FUNC_TOTAL=0
EDGE_SCORE=0
EDGE_PASSED=0
EDGE_TOTAL=0
QUAL_SCORE=0
QUAL_PASSED=0
QUAL_TOTAL=0

# テスト実行関数
run_test() {
    local test_id="$1"
    local test_name="$2"
    local test_points="$3"
    local test_category="$4"  # functional, edge, quality
    local test_func="$5"

    local test_work_dir
    test_work_dir=$(mktemp -d)

    echo "" >> "$TEST_LOG"
    echo "--- $test_id: $test_name ($test_points pts) ---" >> "$TEST_LOG"

    local reason=""
    if $test_func "$test_work_dir" >> "$TEST_LOG" 2>&1; then
        echo "  PASS" >> "$TEST_LOG"
        RESULTS_ID+=("$test_id")
        RESULTS_NAME+=("$test_name")
        RESULTS_POINTS+=("$test_points")
        RESULTS_PASSED+=("true")
        RESULTS_REASON+=("")
        TOTAL_SCORE=$((TOTAL_SCORE + test_points))
        case "$test_category" in
            functional) FUNC_SCORE=$((FUNC_SCORE + test_points)); FUNC_PASSED=$((FUNC_PASSED + 1)) ;;
            edge) EDGE_SCORE=$((EDGE_SCORE + test_points)); EDGE_PASSED=$((EDGE_PASSED + 1)) ;;
            quality) QUAL_SCORE=$((QUAL_SCORE + test_points)); QUAL_PASSED=$((QUAL_PASSED + 1)) ;;
        esac
    else
        reason=$(tail -1 "$TEST_LOG" 2>/dev/null || echo "unknown")
        echo "  FAIL: $reason" >> "$TEST_LOG"
        RESULTS_ID+=("$test_id")
        RESULTS_NAME+=("$test_name")
        RESULTS_POINTS+=("$test_points")
        RESULTS_PASSED+=("false")
        RESULTS_REASON+=("$reason")
    fi

    case "$test_category" in
        functional) FUNC_TOTAL=$((FUNC_TOTAL + 1)) ;;
        edge) EDGE_TOTAL=$((EDGE_TOTAL + 1)) ;;
        quality) QUAL_TOTAL=$((QUAL_TOTAL + 1)) ;;
    esac

    rm -rf "$test_work_dir"
}

export -f run_test 2>/dev/null || true

# テストスイート読み込み・実行
source "$SCRIPT_DIR/test_cases.sh"
source "$SCRIPT_DIR/test_edge_cases.sh"
source "$SCRIPT_DIR/test_code_quality.sh"

# スコアレポート生成
source "$SCRIPT_DIR/score_report.sh"
generate_score_report "$RUN_DIR/scoring_result.json"

# サマリ表示
echo ""
echo "========================================"
echo " BENCHMARK SCORING RESULT"
echo "========================================"
echo " Total Score:    $TOTAL_SCORE / 100"
echo " Functional:     $FUNC_SCORE / 60  ($FUNC_PASSED / $FUNC_TOTAL passed)"
echo " Edge Cases:     $EDGE_SCORE / 20  ($EDGE_PASSED / $EDGE_TOTAL passed)"
echo " Code Quality:   $QUAL_SCORE / 20  ($QUAL_PASSED / $QUAL_TOTAL passed)"
echo "========================================"
echo " Details: $RUN_DIR/scoring_result.json"
echo " Log:     $TEST_LOG"
echo "========================================"
