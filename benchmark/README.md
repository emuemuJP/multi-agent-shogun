# multi-agent-shogun ベンチマーク

マルチエージェントシステムの品質を定量的に評価するベンチマークフレームワーク。

## 概要

**テストアプリケーション** `gradecalc`（成績管理CLI）の構築タスクを通じて、
システム構成の違いによる成果物の品質差を数値で比較する。

## スコアリング（100点満点）

| カテゴリ | 点数 | テスト数 | 内容 |
|----------|------|---------|------|
| 機能テスト (T01-T22) | 60 | 22 | 各要件の正常動作 |
| エッジケース (E01-E12) | 20 | 12 | 境界値・異常入力 |
| コード品質 (Q01-Q07) | 20 | 7 | 構造・命名・ドキュメント |
| **合計** | **100** | **41** | |

## プロセスメトリクス

- 所要時間（秒）
- 通信YAML数
- サブタスク数・完了率
- 軍師レビュー数・指摘件数・精度

## クイックスタート

```bash
# 1. Runディレクトリ作成
RUN_ID="$(date +%Y%m%d_%H%M)_test"
mkdir -p benchmark/runs/$RUN_ID/output

# 2. gradecalc.py を配置（エージェントまたは手動で）
cp path/to/gradecalc.py benchmark/runs/$RUN_ID/output/

# 3. 採点実行
bash benchmark/scoring/run_tests.sh benchmark/runs/$RUN_ID

# 4. 結果確認
cat benchmark/runs/$RUN_ID/scoring_result.json | python3 -m json.tool
```

## 2つのRunを比較

```bash
bash benchmark/compare/compare_runs.sh benchmark/runs/run_a benchmark/runs/run_b
```

## ディレクトリ構成

```
benchmark/
├── spec/            # テストアプリ仕様書
├── scoring/         # 自動テスト・採点スクリプト
├── metrics/         # プロセスメトリクス収集
├── configs/         # システム構成定義
├── compare/         # Run間比較
├── runs/            # 実行結果（.gitignore）
└── procedure.md     # 詳細な実行手順
```

詳細な実行手順は [procedure.md](procedure.md) を参照。
