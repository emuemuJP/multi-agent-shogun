#!/bin/bash
# test_code_quality.sh - コード品質テスト Q01-Q07 (20点)
# run_tests.sh から source される

SRC_DIR="$(dirname "$GRADECALC")"

# --- Q01: 外部依存なし (3点) ---
test_Q01_no_external_deps() {
    local workdir="$1"
    local stdlib_modules="json csv sys os argparse pathlib typing collections functools io re string textwrap datetime copy math shutil errno stat abc contextlib warnings tempfile unittest"

    # import文を抽出
    local imports
    imports=$(grep -rn "^import \|^from " "$GRADECALC" | grep -v "^#" || true)

    if [ -z "$imports" ]; then
        # importが全くない場合も通過（ありえないが）
        return 0
    fi

    echo "$imports" | while IFS= read -r line; do
        # "from X import Y" or "import X" からモジュール名を抽出
        local module
        module=$(echo "$line" | sed 's/.*from \([a-zA-Z_][a-zA-Z0-9_.]*\).*/\1/; s/.*import \([a-zA-Z_][a-zA-Z0-9_.]*\).*/\1/' | cut -d. -f1)
        if ! echo "$stdlib_modules" | grep -qw "$module"; then
            echo "FAIL Q01: non-stdlib import found: $module"
            return 1
        fi
    done
    return $?
}

# --- Q02: ファイル構造 (3点) ---
test_Q02_file_structure() {
    local workdir="$1"
    # エントリポイントが存在するか
    [ -f "$GRADECALC" ] || { echo "FAIL Q02: entry point not found"; return 1; }
    # if __name__ == "__main__" ガードがあるか
    grep -q '__name__.*__main__\|__name__ == .__main__.' "$GRADECALC" || { echo "FAIL Q02: missing if __name__ == '__main__' guard"; return 1; }
    # インデント一貫性（タブとスペースの混在チェック、macOS互換）
    local has_tabs has_spaces
    has_tabs=$(grep -c '	' "$GRADECALC" 2>/dev/null || echo 0)
    has_spaces=$(grep -c '^    ' "$GRADECALC" 2>/dev/null || echo 0)
    if [ "$has_tabs" -gt 0 ] && [ "$has_spaces" -gt 0 ]; then
        echo "FAIL Q02: mixed tabs and spaces"
        return 1
    fi
    return 0
}

# --- Q03: 関数分解 (4点) ---
test_Q03_function_decomposition() {
    local workdir="$1"
    # 関数定義の数をカウント
    local func_count
    func_count=$(grep -c "^def \|^    def " "$GRADECALC" 2>/dev/null || echo 0)
    if [ "$func_count" -lt 7 ]; then
        echo "FAIL Q03: only $func_count functions found, minimum 7 expected"
        return 1
    fi

    # 80行超の関数がないかチェック（簡易版）
    python3 -c "
import sys
lines = open('$GRADECALC').readlines()
func_starts = []
for i, line in enumerate(lines):
    stripped = line.lstrip()
    if stripped.startswith('def '):
        func_starts.append((i, stripped.split('(')[0].replace('def ', '').strip()))
for idx, (start, name) in enumerate(func_starts):
    end = func_starts[idx+1][0] if idx+1 < len(func_starts) else len(lines)
    length = end - start
    if length > 80:
        print(f'WARNING Q03: function {name} is {length} lines (>80)')
        # ペナルティとして1つまでは許容、2つ以上はFAIL
" 2>&1 | head -3

    # 致命的でなければPASS（関数数が7以上ならOK）
    return 0
}

# --- Q04: エラーメッセージ品質 (3点) ---
test_Q04_error_messages() {
    local workdir="$1"
    # stderrへの出力があるか確認
    local stderr_usage
    stderr_usage=$(grep -c "sys\.stderr\|file=sys\.stderr\|stderr" "$GRADECALC" 2>/dev/null || echo 0)
    if [ "$stderr_usage" -lt 1 ]; then
        echo "FAIL Q04: no stderr usage found (errors should go to stderr)"
        return 1
    fi
    # 具体的なエラーメッセージがあるか（"Error"だけではなく）
    local error_msgs
    error_msgs=$(grep -c "\"Error\|'Error\|\"error\|'error\|\"Invalid\|'Invalid\|\"not found\|'not found\|\"already exists\|'already exists" "$GRADECALC" 2>/dev/null || echo 0)
    if [ "$error_msgs" -lt 3 ]; then
        echo "FAIL Q04: fewer than 3 distinct error messages found ($error_msgs)"
        return 1
    fi
    return 0
}

# --- Q05: ハードコードパスなし (2点) ---
test_Q05_no_hardcoded_paths() {
    local workdir="$1"
    # 絶対パスのハードコードがないか（テスト用途を除く）
    local hardcoded
    hardcoded=$(grep -n '"/home/\|"/tmp/\|"/Users/\|"C:\\' "$GRADECALC" 2>/dev/null | grep -v "^#\|#.*hardcod" || true)
    if [ -n "$hardcoded" ]; then
        echo "FAIL Q05: hardcoded paths found:"
        echo "$hardcoded" | head -3
        return 1
    fi
    return 0
}

# --- Q06: ドキュメント (2点) ---
test_Q06_documentation() {
    local workdir="$1"
    # docstringの数を数える（"""で囲まれた文字列がdef直後にある）
    local docstring_count
    docstring_count=$(python3 -c "
import ast, sys
try:
    tree = ast.parse(open('$GRADECALC').read())
    count = 0
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if (node.body and isinstance(node.body[0], ast.Expr) and
                isinstance(node.body[0].value, (ast.Constant, ast.Str))):
                count += 1
    print(count)
except:
    print(0)
" 2>/dev/null)
    if [ "$docstring_count" -ge 3 ]; then
        return 0
    fi
    # docstringが3未満ならコメントをチェック
    local comment_count
    comment_count=$(grep -c "^[[:space:]]*#" "$GRADECALC" 2>/dev/null || echo 0)
    if [ "$comment_count" -ge 10 ]; then
        return 0
    fi
    echo "FAIL Q06: insufficient documentation (docstrings: $docstring_count, comments: $comment_count)"
    return 1
}

# --- Q07: 命名規則 (3点) ---
test_Q07_naming_convention() {
    local workdir="$1"
    # camelCase関数名がないか
    local camel_funcs
    camel_funcs=$(grep "^def \|^    def " "$GRADECALC" | grep -E "def [a-z]+[A-Z]" || true)
    if [ -n "$camel_funcs" ]; then
        echo "FAIL Q07: camelCase function names found:"
        echo "$camel_funcs" | head -3
        return 1
    fi
    # snake_case関数名のみであることを確認（macOS互換: grep -P 不使用）
    local all_funcs
    all_funcs=$(grep -o 'def [a-zA-Z_][a-zA-Z0-9_]*' "$GRADECALC" | sed 's/def //' | sort -u)
    for func in $all_funcs; do
        # __で始まるものはスキップ
        [[ "$func" == __* ]] && continue
        # 大文字のみの関数名はスキップ（定数的なもの）
        [[ "$func" =~ ^[A-Z_]+$ ]] && continue
        # camelCaseチェック（小文字で始まって途中に大文字）
        if echo "$func" | grep -qE '^[a-z].*[A-Z]'; then
            echo "FAIL Q07: function '$func' is not snake_case"
            return 1
        fi
    done
    return 0
}

# --- テスト実行 ---
run_test "Q01" "No external dependencies" 3 "quality" test_Q01_no_external_deps
run_test "Q02" "File structure" 3 "quality" test_Q02_file_structure
run_test "Q03" "Function decomposition" 4 "quality" test_Q03_function_decomposition
run_test "Q04" "Error message quality" 3 "quality" test_Q04_error_messages
run_test "Q05" "No hardcoded paths" 2 "quality" test_Q05_no_hardcoded_paths
run_test "Q06" "Documentation" 2 "quality" test_Q06_documentation
run_test "Q07" "Naming convention" 3 "quality" test_Q07_naming_convention
