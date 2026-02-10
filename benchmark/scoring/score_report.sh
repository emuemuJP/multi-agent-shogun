#!/bin/bash
# score_report.sh - スコアレポートJSON生成
# run_tests.sh から source される

generate_score_report() {
    local output_file="$1"
    local run_id
    run_id=$(basename "$(dirname "$output_file")")

    # テスト結果をJSON配列に変換
    local tests_json="["
    local failures_json="["
    local first_test=true
    local first_fail=true

    for i in "${!RESULTS_ID[@]}"; do
        local id="${RESULTS_ID[$i]}"
        local name="${RESULTS_NAME[$i]}"
        local points="${RESULTS_POINTS[$i]}"
        local passed="${RESULTS_PASSED[$i]}"
        local reason="${RESULTS_REASON[$i]}"

        # JSON文字列のエスケープ
        name=$(echo "$name" | sed 's/"/\\"/g')
        reason=$(echo "$reason" | sed 's/"/\\"/g')

        if [ "$first_test" = true ]; then
            first_test=false
        else
            tests_json+=","
        fi
        tests_json+="{\"id\":\"$id\",\"name\":\"$name\",\"points\":$points,\"passed\":$passed}"

        if [ "$passed" = "false" ]; then
            if [ "$first_fail" = true ]; then
                first_fail=false
            else
                failures_json+=","
            fi
            failures_json+="{\"id\":\"$id\",\"name\":\"$name\",\"points\":$points,\"reason\":\"$reason\"}"
        fi
    done

    tests_json+="]"
    failures_json+="]"

    # JSON出力
    cat > "$output_file" <<JSONEOF
{
  "run_id": "$run_id",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_score": $TOTAL_SCORE,
  "max_score": 100,
  "categories": {
    "functional": {
      "score": $FUNC_SCORE,
      "max": 60,
      "passed": $FUNC_PASSED,
      "total": $FUNC_TOTAL
    },
    "edge_cases": {
      "score": $EDGE_SCORE,
      "max": 20,
      "passed": $EDGE_PASSED,
      "total": $EDGE_TOTAL
    },
    "code_quality": {
      "score": $QUAL_SCORE,
      "max": 20,
      "passed": $QUAL_PASSED,
      "total": $QUAL_TOTAL
    }
  },
  "tests": $tests_json,
  "failures": $failures_json
}
JSONEOF
}
