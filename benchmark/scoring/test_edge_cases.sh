#!/bin/bash
# test_edge_cases.sh - エッジケーステスト E01-E12 (20点)
# run_tests.sh から source される

# --- E01: 空の名前拒否 (2点) ---
test_E01_empty_name() {
    local workdir="$1"
    local df="$workdir/data.json"
    local output
    output=$(gc add-student --name "" --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -ne 0 ] || { echo "FAIL E01: empty name should be rejected (exit code 0)"; return 1; }
    return 0
}

# --- E02: スコア境界値 0と100 (2点) ---
test_E02_score_boundary_valid() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    # スコア0 - 許可されるべき
    gc add-grade --id S001 --subject test1 --score 0 --data-file "$df" > /dev/null 2>&1
    local ec1=$?
    [ $ec1 -eq 0 ] || { echo "FAIL E02: score 0 should be accepted"; return 1; }
    # スコア100 - 許可されるべき
    gc add-grade --id S001 --subject test2 --score 100 --data-file "$df" > /dev/null 2>&1
    local ec2=$?
    [ $ec2 -eq 0 ] || { echo "FAIL E02: score 100 should be accepted"; return 1; }
    return 0
}

# --- E03: 範囲外スコア拒否 (2点) ---
test_E03_score_out_of_range() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    # -1 拒否
    gc add-grade --id S001 --subject test --score -1 --data-file "$df" > /dev/null 2>&1
    local ec1=$?
    [ $ec1 -ne 0 ] || { echo "FAIL E03: score -1 should be rejected"; return 1; }
    # 101 拒否
    gc add-grade --id S001 --subject test --score 101 --data-file "$df" > /dev/null 2>&1
    local ec2=$?
    [ $ec2 -ne 0 ] || { echo "FAIL E03: score 101 should be rejected"; return 1; }
    return 0
}

# --- E04: 非整数スコア拒否 (2点) ---
test_E04_non_integer_score() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    # 小数拒否
    gc add-grade --id S001 --subject test --score 85.5 --data-file "$df" > /dev/null 2>&1
    local ec1=$?
    [ $ec1 -ne 0 ] || { echo "FAIL E04: score 85.5 should be rejected"; return 1; }
    # 文字列拒否
    gc add-grade --id S001 --subject test --score abc --data-file "$df" > /dev/null 2>&1
    local ec2=$?
    [ $ec2 -ne 0 ] || { echo "FAIL E04: score 'abc' should be rejected"; return 1; }
    return 0
}

# --- E05: 存在しない生徒ID (2点) ---
test_E05_nonexistent_student_id() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc add-grade --id S999 --subject math --score 80 --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -ne 0 ] || { echo "FAIL E05: non-existent S999 should be rejected"; return 1; }
    echo "$output" | grep -qi "S999\|not found\|exist\|invalid" || { echo "FAIL E05: error should mention the invalid ID"; return 1; }
    return 0
}

# --- E06: 重複生徒名拒否 (2点) ---
test_E06_duplicate_name() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    local ec=$?
    [ $ec -ne 0 ] || { echo "FAIL E06: duplicate name should be rejected"; return 1; }
    # 重複が保存されていないことも確認
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
names = [s['name'] for s in data.get('students', [])]
if names.count('Alice') != 1:
    print(f'FAIL: expected 1 Alice, got {names.count(\"Alice\")}')
    sys.exit(1)
" || { echo "FAIL E06: duplicate was stored in data file"; return 1; }
    return 0
}

# --- E07: 破損JSONファイル (2点) ---
test_E07_corrupted_json() {
    local workdir="$1"
    local df="$workdir/data.json"
    echo "THIS IS NOT JSON {{{" > "$df"
    local output
    output=$(gc list --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -ne 0 ] || { echo "FAIL E07: corrupted JSON should cause error exit"; return 1; }
    # Pythonトレースバックが出ていないことを確認
    echo "$output" | grep -q "Traceback" && { echo "FAIL E07: Python traceback should not be shown"; return 1; }
    return 0
}

# --- E08: データファイルなしでの読み取り操作 (1点) ---
test_E08_missing_data_file() {
    local workdir="$1"
    local df="$workdir/nonexistent_dir/data.json"
    # listコマンド - クラッシュしないこと
    local output
    output=$(gc list --data-file "$workdir/no_such_file.json" 2>&1)
    local ec=$?
    # クラッシュ（トレースバック）しないこと
    echo "$output" | grep -q "Traceback" && { echo "FAIL E08: should not crash with traceback"; return 1; }
    return 0
}

# --- E09: 非常に長い生徒名 (1点) ---
test_E09_very_long_name() {
    local workdir="$1"
    local df="$workdir/data.json"
    # 101文字の名前
    local long_name
    long_name=$(python3 -c "print('A' * 101)")
    gc add-student --name "$long_name" --data-file "$df" > /dev/null 2>&1
    local ec=$?
    [ $ec -ne 0 ] || { echo "FAIL E09: name over 100 chars should be rejected"; return 1; }
    return 0
}

# --- E10: 不正行を含むCSVインポート (2点) ---
test_E10_import_invalid_rows() {
    local workdir="$1"
    local df="$workdir/data.json"
    local csvfile="$workdir/bad_import.csv"
    cat > "$csvfile" <<'CSV'
student_id,student_name,subject,score
S001,Alice,math,85
BAD_ROW
S002,Bob,english,abc
S003,Charlie,science,75
CSV
    local output stderr_output
    output=$(gc import --file "$csvfile" --data-file "$df" 2>/tmp/bench_e10_stderr)
    stderr_output=$(cat /tmp/bench_e10_stderr)
    rm -f /tmp/bench_e10_stderr
    # 有効な行はインポートされているか
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
students = data.get('students', [])
names = [s['name'] for s in students]
# Alice と Charlie は入っているはず
if 'Alice' not in names:
    print('FAIL: Alice should have been imported')
    sys.exit(1)
if 'Charlie' not in names:
    print('FAIL: Charlie should have been imported')
    sys.exit(1)
" || { echo "FAIL E10: valid rows not imported correctly"; return 1; }
    return 0
}

# --- E11: 存在しないファイルのインポート (1点) ---
test_E11_import_nonexistent_file() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc import --file "$workdir/nonexistent.csv" --data-file "$df" > /dev/null 2>&1
    local ec=$?
    [ $ec -ne 0 ] || { echo "FAIL E11: import of nonexistent file should fail"; return 1; }
    return 0
}

# --- E12: 特殊文字を含む生徒名 (1点) ---
test_E12_special_characters() {
    local workdir="$1"
    local df="$workdir/data.json"
    local csvfile="$workdir/special.csv"
    # カンマとクォートを含む名前
    gc add-student --name "O'Brien" --data-file "$df" > /dev/null 2>&1
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL E12: name with apostrophe should be accepted"; return 1; }
    gc add-grade --id S001 --subject math --score 80 --data-file "$df" > /dev/null 2>&1
    # CSVエクスポートして壊れていないか確認
    gc export --format csv --output "$csvfile" --data-file "$df" > /dev/null 2>&1
    python3 -c "
import csv, sys
with open('$csvfile', newline='') as f:
    reader = csv.reader(f)
    rows = list(reader)
if len(rows) < 2:
    print('FAIL: CSV has less than 2 rows')
    sys.exit(1)
data_row = rows[1]
if \"O'Brien\" not in data_row[1]:
    print(f'FAIL: name not correctly escaped in CSV, got: {data_row[1]}')
    sys.exit(1)
" || { echo "FAIL E12: special chars not handled correctly in CSV"; return 1; }
    return 0
}

# --- テスト実行 ---
run_test "E01" "Empty name rejected" 2 "edge" test_E01_empty_name
run_test "E02" "Score boundary 0 and 100" 2 "edge" test_E02_score_boundary_valid
run_test "E03" "Score out of range" 2 "edge" test_E03_score_out_of_range
run_test "E04" "Non-integer score rejected" 2 "edge" test_E04_non_integer_score
run_test "E05" "Non-existent student ID" 2 "edge" test_E05_nonexistent_student_id
run_test "E06" "Duplicate student name" 2 "edge" test_E06_duplicate_name
run_test "E07" "Corrupted JSON file" 2 "edge" test_E07_corrupted_json
run_test "E08" "Missing data file" 1 "edge" test_E08_missing_data_file
run_test "E09" "Very long name" 1 "edge" test_E09_very_long_name
run_test "E10" "Import invalid rows" 2 "edge" test_E10_import_invalid_rows
run_test "E11" "Import nonexistent file" 1 "edge" test_E11_import_nonexistent_file
run_test "E12" "Special characters" 1 "edge" test_E12_special_characters
