# ベンチマーク実行手順

## 前提条件

- multi-agent-shogun のセットアップ完了（`first_setup.sh` 実行済み）
- Python 3.8+ がインストール済み
- tmux が利用可能

## 手順

### Phase 1: 準備

```bash
cd /path/to/multi-agent-shogun

# config選択（例: 軍師あり構成）
CONFIG_NAME="with_gunshi"

# Runディレクトリ作成
RUN_ID="$(date +%Y%m%d_%H%M)_${CONFIG_NAME}"
mkdir -p "benchmark/runs/$RUN_ID/output"
mkdir -p "benchmark/runs/$RUN_ID/queue_snapshot"

# config記録
cp "benchmark/configs/config_${CONFIG_NAME}.yaml" "benchmark/runs/$RUN_ID/meta_config.yaml"

# タイマー開始
bash benchmark/metrics/start_timer.sh "benchmark/runs/$RUN_ID"
```

### Phase 2: システム起動・タスク投入

```bash
# システム起動
./shutsujin_departure.sh

# エージェント初期化を待機（30秒程度）
sleep 30

# shogun_command.yaml のプレースホルダーを置換
sed "s/__RUN_ID__/$RUN_ID/g; s/__TIMESTAMP__/$(date '+%Y-%m-%dT%H:%M:%S')/g" \
    benchmark/spec/shogun_command.yaml > queue/shogun_to_karo.yaml

# 将軍（shogunペイン）に指示を送信
tmux send-keys -t shogun:0.0 'queue/shogun_to_karo.yaml に新しい指示がある。benchmark/spec/requirements.md を読んで、gradecalcアプリを構築せよ。成果物は benchmark/runs/'"$RUN_ID"'/output/gradecalc.py に配置すること。'
tmux send-keys -t shogun:0.0 Enter
```

### Phase 3: 監視

```bash
# dashboard.md でタスク完了を監視
watch -n 10 cat dashboard.md

# または手動で確認
cat dashboard.md
```

**完了条件**:
- dashboard.md に cmd_benchmark_001 の完了が記載
- `benchmark/runs/$RUN_ID/output/gradecalc.py` が存在

### Phase 4: 結果収集

```bash
# タイマー停止
bash benchmark/metrics/stop_timer.sh "benchmark/runs/$RUN_ID"

# 通信ファイルのスナップショット
cp queue/shogun_to_karo.yaml "benchmark/runs/$RUN_ID/queue_snapshot/"
cp queue/karo_to_gunshi.yaml "benchmark/runs/$RUN_ID/queue_snapshot/" 2>/dev/null || true
cp queue/shogun_to_gunshi.yaml "benchmark/runs/$RUN_ID/queue_snapshot/" 2>/dev/null || true
cp -r queue/tasks/ "benchmark/runs/$RUN_ID/queue_snapshot/tasks/" 2>/dev/null || true
cp -r queue/reports/ "benchmark/runs/$RUN_ID/queue_snapshot/reports/" 2>/dev/null || true
cp dashboard.md "benchmark/runs/$RUN_ID/dashboard_snapshot.md" 2>/dev/null || true
cp status/master_status.yaml "benchmark/runs/$RUN_ID/status_snapshot.yaml" 2>/dev/null || true
```

### Phase 5: 採点

```bash
# 自動テスト実行
bash benchmark/scoring/run_tests.sh "benchmark/runs/$RUN_ID"

# 結果確認
cat "benchmark/runs/$RUN_ID/scoring_result.json" | python3 -m json.tool
```

### Phase 6: プロセスメトリクス収集

```bash
bash benchmark/metrics/collect_process_metrics.sh "benchmark/runs/$RUN_ID"
cat "benchmark/runs/$RUN_ID/process_metrics.json" | python3 -m json.tool
```

### Phase 7: 比較（2回目以降）

```bash
# 2つのRunを比較
bash benchmark/compare/compare_runs.sh \
    "benchmark/runs/20260207_1430_with_gunshi" \
    "benchmark/runs/20260207_1530_without_gunshi"
```

## 軍師なし構成での実行

軍師なし構成で実行する場合、Phase 2 の将軍への指示を以下に変更:

```bash
tmux send-keys -t shogun:0.0 'queue/shogun_to_karo.yaml に新しい指示がある。benchmark/spec/requirements.md を読んで、gradecalcアプリを構築せよ。成果物は benchmark/runs/'"$RUN_ID"'/output/gradecalc.py に配置すること。今回は軍師レビューを省略し、家老は直接足軽に割り当てよ。'
tmux send-keys -t shogun:0.0 Enter
```

## スコアの見方

| 範囲 | 評価 |
|------|------|
| 90-100 | 優秀: 全機能動作、コード品質も良好 |
| 75-89 | 良好: ほとんどの機能が動作、一部エッジケース漏れ |
| 60-74 | 普通: 主要機能は動作、エッジケースや品質に課題 |
| 40-59 | 不十分: 複数の主要機能に問題あり |
| 0-39 | 失敗: 根本的な問題あり |
