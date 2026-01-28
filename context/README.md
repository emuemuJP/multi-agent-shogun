# context ディレクトリ

プロジェクト固有のコンテキストを管理するディレクトリ。

## 目的

- プロジェクトごとの知識・決定事項を保存
- セッション間での情報共有
- 知識混合の防止（プロジェクト間の分離）
- 新規参加者（足軽）への引継ぎ

## ファイル構成

```
context/
  README.md                          ← このファイル
  {project_id}/
    CONTEXT.md                       ← プロジェクト最新状態
    progress.json                    ← 進捗追跡（JSON形式）
    dashboard_yyyymmdd.md            ← 日次dashboard保存
```

## 使い方

### 新規プロジェクト追加時

1. `context/{project_id}/` ディレクトリを作成
2. `context/{project_id}/CONTEXT.md` を作成（テンプレート参照）
3. `context/{project_id}/progress.json` を作成
4. `config/projects.yaml` にプロジェクトを登録

### プロジェクト切り替え時

1. 現プロジェクトの `dashboard.md` を `context/{project_id}/dashboard_yyyymmdd.md` に保存
2. `/clear` でコンテキストをリセット
3. 新プロジェクトの `context/{project_id}/CONTEXT.md` を読み込み
4. 新プロジェクトの `progress.json` で進捗を確認

### 作業再開時

1. `context/{project_id}/CONTEXT.md` を読む
2. `context/{project_id}/progress.json` で進捗を確認
3. 最新の `dashboard_yyyymmdd.md` を参照（必要に応じて）

## CONTEXT.md テンプレート

```markdown
# {project_id} プロジェクトコンテキスト

最終更新: YYYY-MM-DD

## 基本情報

- **プロジェクトID**: {project_id}
- **正式名称**: {name}
- **パス**: {path}
- **Notion URL**: {url}（あれば）

## 概要

{プロジェクトの概要を1-2文で}

## 技術スタック

- **言語**:
- **フレームワーク**:
- **データベース**:

## アーキテクチャ

{簡易図}

## 重要な決定事項

- YYYY-MM-DD: {決定内容}

## 現在の状況

### 完了
- {完了タスク}

### 進行中
- {進行中タスク}

## 注意事項

{プロジェクト固有の注意点}

## 関連ファイル

- 日次記録: context/{project_id}/dashboard_yyyymmdd.md
- 成果物: {path}
```

## progress.json テンプレート

```json
{
  "project_id": "{project_id}",
  "last_updated": "YYYY-MM-DDTHH:MM:SS",
  "phases": [
    {
      "id": "phase_1",
      "name": "フェーズ名",
      "status": "not_started|in_progress|completed",
      "completed_at": null
    }
  ],
  "tasks": [
    {
      "id": "cmd_001",
      "description": "タスク説明",
      "status": "pending|in_progress|completed"
    }
  ],
  "artifacts": [
    "/path/to/artifact"
  ]
}
```

## 更新ルール

- 重要な決定があったら即座に CONTEXT.md を更新
- タスク完了時は progress.json を更新
- プロジェクト切り替え時は dashboard を日付付きで保存
- 不要になった情報は削除（シンプルに保つ）

## Best Practices

参考: [Anthropic Engineering - Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)

- **JSON形式**: 進捗はJSON形式で管理（エージェントが誤って変更しにくい）
- **Git履歴 + 進捗ファイル**: 新セッション開始時に状態を把握
- **物理的分離**: 別プロジェクトは別ディレクトリで管理
