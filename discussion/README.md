# 🎭 Multi-Model Discussion System

複数のAIモデル（Claude, Gemini, Codex）がブレインストーミングや討論を行うtmuxベースのUI。

## 概要

```
┌─────────────────────────────────────────────────────────────┐
│                    discussion session                        │
├──────────────────────────┬──────────────────────────────────┤
│   🟣 Claude              │   🟢 Gemini                      │
│   論理的分析・構造化      │   創造的発想・多角的視点          │
├──────────────────────────┼──────────────────────────────────┤
│   🟡 Codex               │   📊 Visualizer                  │
│   技術的実装・実用性      │   討論の可視化・進行役            │
└──────────────────────────┴──────────────────────────────────┘
```

## クイックスタート

```bash
# 1. 討論システムを起動
cd discussion
./discussion_start.sh

# 2. セッションにアタッチ
tmux attach -t discussion

# 3. Visualizerペイン（右下）で討論を開始
# 「AIの倫理について討論を開始してください」
```

## ディレクトリ構成

```
discussion/
├── discussion_start.sh      # 起動スクリプト
├── config/
│   └── settings.yaml        # 設定ファイル
├── queue/
│   ├── topic.yaml           # 討論トピック
│   ├── consensus.yaml       # 合意状況
│   ├── turns/               # 各ラウンドの発言
│   └── responses/           # レスポンス
├── instructions/
│   ├── claude.md            # Claude用指示書
│   ├── gemini.md            # Gemini用指示書
│   ├── codex.md             # Codex用指示書
│   └── visualizer.md        # Visualizer用指示書
└── visualizer/
    └── dashboard.md         # 討論ダッシュボード
```

## 各モデルの特徴

| モデル | 特徴 | 役割 |
|--------|------|------|
| **Claude** | 論理的・構造的 | 問題を分解し、体系的に議論 |
| **Gemini** | 創造的・多角的 | 新しい視点、代替案を提示 |
| **Codex** | 実装志向・実用的 | 技術的実現可能性を評価 |
| **Visualizer** | 中立・記録役 | 進行管理、可視化、合意追跡 |

## 討論フロー

```
1. Opening Phase (1ラウンド)
   └── 各モデルが初期見解を述べる

2. Debate Phase (5ラウンド)
   └── 意見交換、反論、質問

3. Synthesis Phase (2ラウンド)
   └── 合意形成、結論導出
```

## 通信プロトコル

### イベント駆動
- ポーリング禁止（API節約）
- YAMLファイルでメッセージ交換
- tmux send-keys で通知

### ファイルフロー
```
User → Visualizer: 口頭でトピック指示
Visualizer → topic.yaml: トピック設定
Visualizer → 各モデル: send-keys で通知
各モデル → turns/round_N_*.yaml: 発言を書く
各モデル → Visualizer: send-keys で通知
Visualizer → dashboard.md: 可視化更新
Visualizer → consensus.yaml: 合意追跡
```

## tmux操作

```bash
# セッションにアタッチ
tmux attach -t discussion

# ペイン間移動
Ctrl+b → 矢印キー

# ペインをズーム（フルスクリーン）
Ctrl+b z

# セッション終了
tmux kill-session -t discussion
```

## カスタマイズ

### モデルの追加・変更

`config/settings.yaml` を編集：

```yaml
models:
  - id: claude
    name: "Claude"
    pane: 0
    color: "1;35"
    role: "論理的分析"
  # 新しいモデルを追加
  - id: gpt4
    name: "GPT-4"
    pane: 1
    color: "1;32"
    role: "汎用的な分析"
```

### 討論ルールの変更

```yaml
discussion:
  max_rounds: 10        # 最大ラウンド数
  turn_timeout: 120     # ターンタイムアウト（秒）
  consensus_threshold: 2 # 合意に必要な最小モデル数
```

## 注意事項

- 現在の実装では、各ペインで同じClaude CLI（`claude`）を使用しています
- 異なるモデル（Gemini, Codex）を実際に使用するには、各ペインで異なるCLI/APIを呼び出す必要があります
- 指示書（instructions/*.md）で各モデルの「人格」を定義しています

## トラブルシューティング

### セッションが起動しない
```bash
# 既存セッションを強制終了
tmux kill-server
# 再起動
./discussion_start.sh
```

### ペインが応答しない
```bash
# 特定ペインにEnterを送信
tmux send-keys -t discussion:0.X Enter
```

## ライセンス

MIT License
