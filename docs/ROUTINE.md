# Claude Code Routine（クラウドスケジュール実行）

Claude Code の [Routine](https://code.claude.com/docs/en/web-scheduled-tasks) 機能を使って、Anthropic クラウド上で自動実行する方法です。

## クラウド実行の注意点

Anthropic クラウドの IP レンジは CloudFlare 等の bot 検知で 403 ブロックされやすく、**Phase 3 のファクトチェックが実質機能しない** ことが実測されています。

ファクトチェックを重視する場合はローカル実行（[`local-runner/`](../local-runner/)）を推奨します。Routine は:

- 常時起動マシンがない場合の fallback
- Phase 1・2 のみ運用し、Phase 3 はレポート生成日とは別日に手動実行する
- 複数環境の冗長化（ローカルが失敗したときの予備）

といった用途に向いています。

## セットアップ

1. https://claude.ai/code/scheduled にアクセス
2. 3 つの Routine を作成（cron 表現は UTC）:
   - Phase 1: `0 19 * * *` (UTC 19:00 = JST 04:00)
   - Phase 2: `0 20 * * *` (UTC 20:00 = JST 05:00)
   - Phase 3: `0 21 * * *` (UTC 21:00 = JST 06:00)
3. 各 Routine の設定:
   - **Repository**: あなたの curation リポジトリ（例: `https://github.com/<YOUR_USERNAME>/<YOUR_REPO>`）
   - **Model**: `claude-sonnet-4-6`（推奨）
   - **Allowed Tools**: `Bash`, `Read`, `Write`, `Edit`, `Glob`, `Grep`, `WebSearch`, `WebFetch`
   - **Prompt**:

### Phase 1 Routine のプロンプト

```
config/prompts/phase1.md を読み、その手順に従って Phase 1（リサーチ）を実行してください。

重要:
- サブエージェント（Agent/Task ツール）は使わない
- 単一セッションであなた自身がリサーチを実行する
- pipeline/YYYY-MM-DD ブランチに research-brief.md を commit & push する
- WebFetch が 403 なら python3 scripts/fetch.py にフォールバックする
- 失敗時は gh issue create で通知する
```

### Phase 2 Routine のプロンプト

```
config/prompts/phase2.md を読み、その手順に従って Phase 2（執筆）を実行してください。

重要:
- サブエージェント（Agent/Task ツール）は使わない
- pipeline/YYYY-MM-DD ブランチから research-brief.md を読み、同ブランチに reports/YYYY/MM/DD/*.md を commit & push する
- Phase 1 が未完了なら SKIPPED で終了する
- 失敗時は gh issue create で通知する
```

### Phase 3 Routine のプロンプト

```
config/prompts/phase3.md を読み、その手順に従って Phase 3（ファクトチェック + 修正 + main へ cherry-pick）を実行してください。

重要:
- サブエージェント（Agent/Task ツール）は使わない
- pipeline/YYYY-MM-DD ブランチの reports を検証し、必要に応じて修正してから main に cherry-pick する
- WebFetch が 403 なら python3 scripts/fetch.py にフォールバックする
- Phase 2 が未完了なら SKIPPED で終了する
- 失敗時は gh issue create で通知する
```

## ローカル + クラウドの並行運用

ローカルが主で、クラウドを fallback にする場合:

- ローカル: JST 03:30 / 04:30 / 05:30
- クラウド: JST 04:00 / 05:00 / 06:00（ローカルが 30 分早く動く）

ローカル成功時、クラウドは冪等性チェック（Step 1 の `-f` テスト）で SKIPPED になります。

## トラブルシューティング

セッションログは `claude.ai/code/scheduled/<trigger_id>` から確認できます。失敗したセッションを開いて、どの Step で止まったか、どのツールでエラーが出たかを確認してください。
