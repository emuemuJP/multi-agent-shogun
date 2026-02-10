#!/bin/bash
# test_cases.sh - 機能テスト T01-T22 (60点)
# run_tests.sh から source される

gc() {
    python3 "$GRADECALC" "$@"
}

# --- T01: ヘルプ出力 (2点) ---
test_T01_help_output() {
    local workdir="$1"
    local output
    output=$(gc --help 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T01: exit code $ec, expected 0"; return 1; }
    echo "$output" | grep -qi "add-student" || { echo "FAIL T01: help missing add-student"; return 1; }
    echo "$output" | grep -qi "add-grade" || { echo "FAIL T01: help missing add-grade"; return 1; }
    echo "$output" | grep -qi "average" || { echo "FAIL T01: help missing average"; return 1; }
    echo "$output" | grep -qi "list" || { echo "FAIL T01: help missing list"; return 1; }
    echo "$output" | grep -qi "failing" || { echo "FAIL T01: help missing failing"; return 1; }
    echo "$output" | grep -qi "export" || { echo "FAIL T01: help missing export"; return 1; }
    echo "$output" | grep -qi "import" || { echo "FAIL T01: help missing import"; return 1; }
    return 0
}

# --- T02: 最初の生徒追加 (3点) ---
test_T02_add_first_student() {
    local workdir="$1"
    local df="$workdir/data.json"
    local output
    output=$(gc add-student --name "Alice" --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T02: exit code $ec"; return 1; }
    echo "$output" | grep -q "S001" || { echo "FAIL T02: output missing S001"; return 1; }
    echo "$output" | grep -q "Alice" || { echo "FAIL T02: output missing Alice"; return 1; }
    [ -f "$df" ] || { echo "FAIL T02: data file not created"; return 1; }
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
s = data.get('students', [])
if len(s) != 1: sys.exit(1)
if s[0]['name'] != 'Alice': sys.exit(1)
if s[0]['id'] != 'S001': sys.exit(1)
" || { echo "FAIL T02: JSON content incorrect"; return 1; }
    return 0
}

# --- T03: 複数生徒追加 (3点) ---
test_T03_add_multiple_students() {
    local workdir="$1"
    local df="$workdir/data.json"
    local o1 o2 o3
    o1=$(gc add-student --name "Alice" --data-file "$df" 2>&1)
    o2=$(gc add-student --name "Bob" --data-file "$df" 2>&1)
    o3=$(gc add-student --name "Charlie" --data-file "$df" 2>&1)
    echo "$o1" | grep -q "S001" || { echo "FAIL T03: first student not S001"; return 1; }
    echo "$o2" | grep -q "S002" || { echo "FAIL T03: second student not S002"; return 1; }
    echo "$o3" | grep -q "S003" || { echo "FAIL T03: third student not S003"; return 1; }
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
if len(data.get('students', [])) != 3: sys.exit(1)
" || { echo "FAIL T03: expected 3 students in JSON"; return 1; }
    return 0
}

# --- T04: 成績追加（基本）(3点) ---
test_T04_add_grade_basic() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc add-grade --id S001 --subject math --score 85 --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T04: exit code $ec"; return 1; }
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
grades = data['students'][0].get('grades', [])
if len(grades) != 1: sys.exit(1)
if grades[0]['subject'] != 'math': sys.exit(1)
if grades[0]['score'] != 85: sys.exit(1)
" || { echo "FAIL T04: grade not stored correctly in JSON"; return 1; }
    return 0
}

# --- T05: 一人に複数成績 (3点) ---
test_T05_multiple_grades() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 85 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject english --score 72 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject science --score 90 --data-file "$df" > /dev/null 2>&1
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
grades = data['students'][0].get('grades', [])
if len(grades) != 3: print(f'got {len(grades)} grades'); sys.exit(1)
subjects = {g['subject'] for g in grades}
if subjects != {'math', 'english', 'science'}: sys.exit(1)
" || { echo "FAIL T05: 3 grades not stored correctly"; return 1; }
    return 0
}

# --- T06: 成績上書き (3点) ---
test_T06_grade_overwrite() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 85 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 92 --data-file "$df" > /dev/null 2>&1
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
grades = data['students'][0].get('grades', [])
math_grades = [g for g in grades if g['subject'] == 'math']
if len(math_grades) != 1:
    print(f'FAIL: expected 1 math grade, got {len(math_grades)} (duplicate instead of overwrite)')
    sys.exit(1)
if math_grades[0]['score'] != 92:
    print(f'FAIL: expected score 92, got {math_grades[0][\"score\"]}')
    sys.exit(1)
" || { echo "FAIL T06: grade not overwritten correctly"; return 1; }
    return 0
}

# --- T07: 科目名の大文字小文字統一 (2点) ---
test_T07_subject_case_insensitive() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject "Math" --score 85 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject "MATH" --score 90 --data-file "$df" > /dev/null 2>&1
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
grades = data['students'][0].get('grades', [])
math_grades = [g for g in grades if g['subject'].lower() == 'math']
if len(math_grades) != 1:
    print(f'FAIL: expected 1 math grade after case-insensitive overwrite, got {len(math_grades)}')
    sys.exit(1)
if math_grades[0]['score'] != 90:
    print(f'FAIL: expected score 90 after overwrite, got {math_grades[0][\"score\"]}')
    sys.exit(1)
if math_grades[0]['subject'] != 'math':
    print(f'FAIL: subject should be lowercase \"math\", got \"{math_grades[0][\"subject\"]}\"')
    sys.exit(1)
" || { echo "FAIL T07: case-insensitive subject handling broken"; return 1; }
    return 0
}

# --- T08: 生徒別平均 (4点) ---
test_T08_average_by_student() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 80 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject english --score 70 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 90 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject science --score 60 --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc average --by student --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T08: exit code $ec"; return 1; }
    echo "$output" | grep -q "75.0" || { echo "FAIL T08: Alice average 75.0 not found"; return 1; }
    echo "$output" | grep -q "Alice" || { echo "FAIL T08: Alice name not found"; return 1; }
    echo "$output" | grep -q "Bob" || { echo "FAIL T08: Bob name not found"; return 1; }
    return 0
}

# --- T09: 科目別平均 (4点) ---
test_T09_average_by_subject() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 80 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject english --score 70 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 90 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject science --score 60 --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc average --by subject --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T09: exit code $ec"; return 1; }
    echo "$output" | grep -q "85.0" || { echo "FAIL T09: math average 85.0 not found"; return 1; }
    echo "$output" | grep -q "70.0" || { echo "FAIL T09: english average 70.0 not found"; return 1; }
    echo "$output" | grep -q "60.0" || { echo "FAIL T09: science average 60.0 not found"; return 1; }
    return 0
}

# --- T10: 特定生徒の平均 (2点) ---
test_T10_average_specific_student() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 80 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject english --score 70 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 90 --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc average --by student --id S001 --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T10: exit code $ec"; return 1; }
    echo "$output" | grep -q "Alice" || { echo "FAIL T10: Alice not found"; return 1; }
    echo "$output" | grep -qi "Bob" && { echo "FAIL T10: Bob should not appear"; return 1; }
    return 0
}

# --- T11: 一覧デフォルトソート (3点) ---
test_T11_list_default() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Charlie" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 80 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 90 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S003 --subject math --score 70 --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc list --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T11: exit code $ec"; return 1; }
    # S001が最初に来ること（ID昇順）
    local first_line
    first_line=$(echo "$output" | head -1)
    echo "$first_line" | grep -q "S001" || { echo "FAIL T11: first line should be S001 (default sort by ID)"; return 1; }
    # 3行あること
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')
    [ "$line_count" -ge 3 ] || { echo "FAIL T11: expected at least 3 lines, got $line_count"; return 1; }
    return 0
}

# --- T12: 平均降順ソート (3点) ---
test_T12_list_sort_avg_desc() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Charlie" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 70 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 90 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S003 --subject math --score 80 --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc list --sort avg --order desc --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T12: exit code $ec"; return 1; }
    local first_line
    first_line=$(echo "$output" | head -1)
    echo "$first_line" | grep -q "Bob" || { echo "FAIL T12: Bob (90) should be first in avg desc sort"; return 1; }
    return 0
}

# --- T13: 名前ソート (2点) ---
test_T13_list_sort_name() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Charlie" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc list --sort name --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T13: exit code $ec"; return 1; }
    local first_line
    first_line=$(echo "$output" | head -1)
    echo "$first_line" | grep -q "Alice" || { echo "FAIL T13: Alice should be first in name sort"; return 1; }
    return 0
}

# --- T14: 不合格者検出（基本）(3点) ---
test_T14_failing_basic() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 80 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject english --score 45 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 90 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject english --score 70 --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc failing --threshold 60 --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T14: exit code $ec"; return 1; }
    echo "$output" | grep -q "Alice" || { echo "FAIL T14: Alice should be listed as failing"; return 1; }
    echo "$output" | grep -q "45" || { echo "FAIL T14: english=45 should appear"; return 1; }
    echo "$output" | grep -qi "Bob" && { echo "FAIL T14: Bob should not appear as failing"; return 1; }
    return 0
}

# --- T15: カスタム閾値 (2点) ---
test_T15_failing_custom_threshold() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 75 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject english --score 65 --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc failing --threshold 80 --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T15: exit code $ec"; return 1; }
    echo "$output" | grep -q "Alice" || { echo "FAIL T15: Alice should fail with threshold 80"; return 1; }
    echo "$output" | grep -q "75" || { echo "FAIL T15: math=75 should appear below threshold 80"; return 1; }
    return 0
}

# --- T16: CSVエクスポート（ファイル）(4点) ---
test_T16_csv_export_file() {
    local workdir="$1"
    local df="$workdir/data.json"
    local csvfile="$workdir/export.csv"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 85 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject english --score 72 --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 90 --data-file "$df" > /dev/null 2>&1
    gc export --format csv --output "$csvfile" --data-file "$df" > /dev/null 2>&1
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T16: exit code $ec"; return 1; }
    [ -f "$csvfile" ] || { echo "FAIL T16: CSV file not created"; return 1; }
    # ヘッダー確認
    local header
    header=$(head -1 "$csvfile")
    echo "$header" | grep -qi "student_id" || { echo "FAIL T16: CSV header missing student_id"; return 1; }
    # データ行数（ヘッダー除く）= 3
    local data_lines
    data_lines=$(tail -n +2 "$csvfile" | wc -l | tr -d ' ')
    [ "$data_lines" -eq 3 ] || { echo "FAIL T16: expected 3 data rows, got $data_lines"; return 1; }
    return 0
}

# --- T17: CSVエクスポート（stdout）(2点) ---
test_T17_csv_export_stdout() {
    local workdir="$1"
    local df="$workdir/data.json"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 85 --data-file "$df" > /dev/null 2>&1
    local output
    output=$(gc export --format csv --data-file "$df" 2>/dev/null)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T17: exit code $ec"; return 1; }
    echo "$output" | grep -qi "student_id" || { echo "FAIL T17: stdout CSV missing header"; return 1; }
    echo "$output" | grep -q "S001" || { echo "FAIL T17: stdout CSV missing S001"; return 1; }
    return 0
}

# --- T18: CSVインポート (4点) ---
test_T18_csv_import() {
    local workdir="$1"
    local df1="$workdir/data1.json"
    local df2="$workdir/data2.json"
    local csvfile="$workdir/transfer.csv"
    # データ作成 → エクスポート
    gc add-student --name "Alice" --data-file "$df1" > /dev/null 2>&1
    gc add-student --name "Bob" --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 85 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 90 --data-file "$df1" > /dev/null 2>&1
    gc export --format csv --output "$csvfile" --data-file "$df1" > /dev/null 2>&1
    # 新しいデータファイルにインポート
    local output
    output=$(gc import --file "$csvfile" --data-file "$df2" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T18: exit code $ec"; return 1; }
    # インポート先にデータが入っているか
    python3 -c "
import json, sys
with open('$df2') as f:
    data = json.load(f)
students = data.get('students', [])
if len(students) < 2:
    print(f'FAIL: expected 2+ students, got {len(students)}')
    sys.exit(1)
" || { echo "FAIL T18: imported data incorrect"; return 1; }
    return 0
}

# --- T19: インポートで新規生徒作成 (3点) ---
test_T19_import_creates_students() {
    local workdir="$1"
    local df="$workdir/data.json"
    local csvfile="$workdir/import.csv"
    # 既存生徒を1人追加
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    gc add-grade --id S001 --subject math --score 80 --data-file "$df" > /dev/null 2>&1
    # 新しい生徒を含むCSVを作成
    cat > "$csvfile" <<'CSV'
student_id,student_name,subject,score
S001,Alice,math,85
S005,Dave,math,70
S005,Dave,english,80
CSV
    local output
    output=$(gc import --file "$csvfile" --data-file "$df" 2>&1)
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T19: exit code $ec"; return 1; }
    python3 -c "
import json, sys
with open('$df') as f:
    data = json.load(f)
students = data.get('students', [])
names = [s['name'] for s in students]
if 'Dave' not in names:
    print('FAIL: Dave not created by import')
    sys.exit(1)
" || { echo "FAIL T19: new student not created by import"; return 1; }
    return 0
}

# --- T20: カスタムデータファイルパス (2点) ---
test_T20_custom_data_file() {
    local workdir="$1"
    local df="$workdir/subdir/custom.json"
    mkdir -p "$workdir/subdir"
    gc add-student --name "Alice" --data-file "$df" > /dev/null 2>&1
    local ec=$?
    [ $ec -eq 0 ] || { echo "FAIL T20: exit code $ec"; return 1; }
    [ -f "$df" ] || { echo "FAIL T20: custom data file not created at $df"; return 1; }
    # デフォルトパスに作成されていないことを確認
    [ ! -f "$workdir/gradecalc_data.json" ] || { echo "FAIL T20: default data file should not be created"; return 1; }
    return 0
}

# --- T21: データなし時のメッセージ (2点) ---
test_T21_empty_data_messages() {
    local workdir="$1"
    local df="$workdir/empty.json"
    # list
    local output
    output=$(gc list --data-file "$df" 2>&1)
    echo "$output" | grep -qi "no students\|no data\|0 students\|empty" || { echo "FAIL T21: list on empty should show no-data message"; return 1; }
    # failing
    output=$(gc failing --data-file "$df" 2>&1)
    echo "$output" | grep -qi "no failing\|no students\|no data\|0\|empty\|none" || { echo "FAIL T21: failing on empty should show appropriate message"; return 1; }
    return 0
}

# --- T22: CSVラウンドトリップ整合性 (3点) ---
test_T22_csv_roundtrip() {
    local workdir="$1"
    local df1="$workdir/data1.json"
    local df2="$workdir/data2.json"
    local csv1="$workdir/export1.csv"
    local csv2="$workdir/export2.csv"
    # 5生徒×3科目のデータ作成
    for name in "Alice" "Bob" "Charlie" "Dave" "Eve"; do
        gc add-student --name "$name" --data-file "$df1" > /dev/null 2>&1
    done
    gc add-grade --id S001 --subject math --score 80 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S001 --subject english --score 70 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S001 --subject science --score 90 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S002 --subject math --score 85 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S002 --subject english --score 75 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S002 --subject science --score 65 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S003 --subject math --score 60 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S003 --subject english --score 50 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S003 --subject science --score 95 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S004 --subject math --score 92 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S004 --subject english --score 88 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S004 --subject science --score 77 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S005 --subject math --score 55 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S005 --subject english --score 62 --data-file "$df1" > /dev/null 2>&1
    gc add-grade --id S005 --subject science --score 71 --data-file "$df1" > /dev/null 2>&1
    # エクスポート → インポート → エクスポート
    gc export --format csv --output "$csv1" --data-file "$df1" > /dev/null 2>&1
    gc import --file "$csv1" --data-file "$df2" > /dev/null 2>&1
    gc export --format csv --output "$csv2" --data-file "$df2" > /dev/null 2>&1
    # 差分チェック
    if ! diff -q "$csv1" "$csv2" > /dev/null 2>&1; then
        echo "FAIL T22: CSV roundtrip not identical"
        diff "$csv1" "$csv2" | head -5
        return 1
    fi
    return 0
}

# --- テスト実行 ---
run_test "T01" "Help output" 2 "functional" test_T01_help_output
run_test "T02" "Add first student" 3 "functional" test_T02_add_first_student
run_test "T03" "Add multiple students" 3 "functional" test_T03_add_multiple_students
run_test "T04" "Add grade basic" 3 "functional" test_T04_add_grade_basic
run_test "T05" "Multiple grades for one student" 3 "functional" test_T05_multiple_grades
run_test "T06" "Grade overwrite" 3 "functional" test_T06_grade_overwrite
run_test "T07" "Subject case insensitivity" 2 "functional" test_T07_subject_case_insensitive
run_test "T08" "Average by student" 4 "functional" test_T08_average_by_student
run_test "T09" "Average by subject" 4 "functional" test_T09_average_by_subject
run_test "T10" "Average specific student" 2 "functional" test_T10_average_specific_student
run_test "T11" "List default sort" 3 "functional" test_T11_list_default
run_test "T12" "List sort by avg desc" 3 "functional" test_T12_list_sort_avg_desc
run_test "T13" "List sort by name" 2 "functional" test_T13_list_sort_name
run_test "T14" "Failing students basic" 3 "functional" test_T14_failing_basic
run_test "T15" "Failing custom threshold" 2 "functional" test_T15_failing_custom_threshold
run_test "T16" "CSV export to file" 4 "functional" test_T16_csv_export_file
run_test "T17" "CSV export to stdout" 1 "functional" test_T17_csv_export_stdout
run_test "T18" "CSV import" 4 "functional" test_T18_csv_import
run_test "T19" "Import creates students" 3 "functional" test_T19_import_creates_students
run_test "T20" "Custom data file path" 2 "functional" test_T20_custom_data_file
run_test "T21" "Empty data messages" 1 "functional" test_T21_empty_data_messages
run_test "T22" "CSV roundtrip integrity" 3 "functional" test_T22_csv_roundtrip
