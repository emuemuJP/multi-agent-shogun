# gradecalc - CLI成績管理ツール仕様書

> Version: 1.0.0
> ベンチマーク用テストアプリケーション

## 概要

Python標準ライブラリのみで実装するCLI成績管理ツール。
生徒の登録、成績の追加・集計、CSV入出力を行う。

## 実行方法

```
python3 gradecalc.py <command> [options]
```

---

## R01 - CLIエントリポイント

- `python3 gradecalc.py --help` でヘルプを表示（exit code 0）
- 引数なしでもヘルプを表示（exit code 0）
- ヘルプには全コマンド名を含むこと: `add-student`, `add-grade`, `average`, `list`, `failing`, `export`, `import`
- 不明なコマンドは exit code 1 + エラーメッセージ

## R02 - データ永続化（JSON）

- データファイル: デフォルト `gradecalc_data.json`（カレントディレクトリ）
- `--data-file <path>` で任意のパスに変更可能（全コマンド共通オプション）
- ファイルが存在しない場合、空のデータ構造で新規作成
- JSONスキーマ:

```json
{
  "students": [
    {
      "id": "S001",
      "name": "Tanaka Taro",
      "grades": [
        {"subject": "math", "score": 85},
        {"subject": "english", "score": 72}
      ]
    }
  ]
}
```

## R03 - 生徒追加

```
python3 gradecalc.py add-student --name "Tanaka Taro"
```

- IDは自動採番: `S001`, `S002`, ... （既存IDの最大値+1）
- 出力: `Added: S001 Tanaka Taro`
- 重複名（完全一致）は拒否: exit code 1 + エラーメッセージ
- 名前: 空文字不可、最大100文字

## R04 - 成績追加

```
python3 gradecalc.py add-grade --id S001 --subject math --score 85
```

- 科目名: 大文字小文字を区別しない（内部的にlowercaseで保存）
- スコア: 整数 0-100 のみ許可
- 存在しないIDはエラー: exit code 1
- 同一生徒+科目の成績が既に存在する場合は**上書き**（追加ではない）
- 出力: `Grade added: S001 math 85`

## R05 - 平均計算

```
python3 gradecalc.py average --by student [--id S001]
python3 gradecalc.py average --by subject
```

- `--by student`: 生徒別の平均（全科目の平均）。ID順にソート
  - 出力形式: `S001 Tanaka Taro: 78.5`
- `--by subject`: 科目別の平均（全生徒の平均）。アルファベット順にソート
  - 出力形式: `math: 82.3`
- 平均は小数第1位に丸め
- 成績がない生徒は `S001 Tanaka Taro: N/A`
- `--id S001` で特定生徒のみ表示

## R06 - 一覧表示

```
python3 gradecalc.py list [--sort name|avg|id] [--order asc|desc]
```

- デフォルト: ID昇順
- 出力形式（タブ区切り）: `S001\tTanaka Taro\t78.5\t3 subjects`
- `--sort avg`: 平均点でソート
- `--sort name`: 名前のアルファベット順
- 生徒がいない場合: `No students found.`

## R07 - 不合格者検出

```
python3 gradecalc.py failing [--threshold 60]
```

- デフォルト閾値: 60
- いずれかの科目が閾値**未満**の生徒をリスト
- 出力形式: `S001 Tanaka Taro: english=45 (below 60)`
- 不合格科目が複数ある場合は全て表示
- 不合格者なし: `No failing students found.`

## R08 - CSVエクスポート

```
python3 gradecalc.py export --format csv [--output grades.csv]
```

- CSV形式: `student_id,student_name,subject,score`
- 1行 = 1生徒×1科目
- ソート: student_id順、次に科目アルファベット順
- `--output` 省略時はstdoutに出力
- ヘッダー行を含む
- 特殊文字（カンマ、引用符）を正しくエスケープ

## R09 - CSVインポート

```
python3 gradecalc.py import --file grades.csv
```

- R08と同じフォーマット（ヘッダー行必須）
- 存在しない生徒は新規作成（IDはCSV内のIDを使用）
- 既存の生徒+科目は成績を上書き
- 出力: `Imported: 5 students, 15 grades (3 new students, 2 updated grades)`
- 不正な行はスキップし、stderrに警告出力
- ファイル不存在: exit code 1 + エラーメッセージ

## R10 - 入力バリデーション・エラーハンドリング

全コマンド共通:
- 全入力を操作実行前に検証
- エラーメッセージはstderrに出力
- エラー時は exit code 1
- 破損/不正なJSONファイルに対して適切にエラー表示（Pythonトレースバックを出さない）
- ファイル権限エラーも適切に処理
- スコア: 負の値、100超、非整数を拒否
- 名前: 空文字、100文字超を拒否
