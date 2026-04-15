# カスタマイズガイド

AI Curation Framework を自分のニーズに合わせて拡張する方法です。

## トピック設定

`config/topics.yml` が全ての起点です。

### カテゴリを増やす・減らす

デフォルトは 6 カテゴリ（core/domain/region/cross/academic/serendipity）ですが、自由に変更できます:

```yaml
topics:
  - name: "あなたのトピック"
    category: mycategory   # 新カテゴリを定義してよい
    description: "..."
    keywords: [...]

rotation:
  daily_topics: 3
  rules:
    - "毎回1件は mycategory から選ぶ"
    - "..."
```

`rotation.rules` に記載されたルールは Phase 1 のプロンプトが参照してトピックを選定します。

### 議題数を変える

`rotation.daily_topics` の数値を変更。3〜6 件くらいが推奨範囲です（多すぎると Phase 1 のツール予算を超えます）。

### serendipity を無効化

```yaml
serendipity:
  enabled: false
```

## プロンプトのカスタマイズ

`config/prompts/phase{1,2,3}.md` を直接編集できます。特によく変更するポイント:

### Phase 1: ツール使用予算

デフォルトは 60 回目標（40 回で縮退発動）。より少ないトピック数 / 広いリサーチをしたい場合は調整:

```markdown
## 原則
- ツール使用回数は **全体で60回以内** を目標   ← ここの数字
- 各トピック WebSearch は **最大2回まで**     ← ここ
```

### Phase 2: 記事の構成

議題ファイルのセクション構成（概要 / 詳細 / 考察 / 参考文献）を変えたい場合、`Step 4: レポート生成` のテンプレート部分を編集。

### Phase 3: ファクトチェックの厳しさ

デフォルトは Inaccurate/Fabricated/Not in Source が 1 件でもあれば FAIL。より厳しく / 緩くしたい場合、`Step 3: 総合判定` の基準を変更。

### 言語

プロンプトはデフォルト日本語ですが、全体を英語に書き換えることも可能です。その場合:
- 3 つの phase*.md を英訳
- topics.yml の `description` も英語に
- 出力されるレポートも英語になります

## スケジュール

### 実行頻度を変える

**週次にしたい場合**（例: 毎週月曜）:

```bash
# systemd timer の OnCalendar を変更
OnCalendar=Mon *-*-* 03:30:00 Asia/Tokyo
```

ただし週次にする場合、`reports/YYYY/MM/DD/` という日付ディレクトリ構造との整合性を考える必要があります。週次運用なら `reports/YYYY/WW/` のような週番号ディレクトリに変更する、あるいは実行日の YYYY/MM/DD をそのまま使う、などのポリシーを決めてください（現状のプロンプトは YYYY/MM/DD 前提）。

**平日だけ実行**:

```
# cron
30 3 * * 1-5 /bin/bash .../run-phase.sh 1
```

### 時刻を変える

JST 以外のタイムゾーンで運用する場合は:
- systemd timer: `OnCalendar=... Asia/Tokyo` を自分の TZ に
- cron: 環境変数 `TZ` を設定
- Windows Task Scheduler: OS のローカル時刻基準

## Claude Code の実行設定

### ツール許可の制限

デフォルトでは幅広く許可しています（`Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch`）。セキュリティ上特定のツールを禁じたい場合は `CURATION_CLAUDE_ARGS` 環境変数を編集:

```bash
# runner.env の例
CURATION_CLAUDE_ARGS="--allowedTools Read,Glob,Grep,WebSearch,WebFetch --max-turns 80"
# Bash を外すとプロンプト内の git 操作等ができなくなるので注意
```

### ツール使用回数の上限

`--max-turns` は Claude Code が呼び出す全ツールのカウントです。デフォルト 80 回で Phase 1 の予算（60）と Phase 2/3 の 40 に余裕を持たせていますが、ハイパフォーマンスマシンでトラブルが出にくい環境なら上げても OK。

## レポートの閲覧環境

### GitHub Pages を有効化

main ブランチの `/reports` 配下を GitHub Pages で公開すれば、Web で閲覧できます。元のプロジェクト（daily-curation-reports）では `docs/` に PWA を置いて Android スマホから閲覧する構成にしていました。

### Obsidian / ノートアプリと連携

`reports/` ディレクトリを Obsidian の Vault として取り込めば、バックリンク付きで閲覧できます。Markdown の脚注記法もそのまま機能します。

## 失敗通知のカスタマイズ

各 Phase はエラー時に `gh issue create` で Issue を立てます。通知先を変えたい場合:

- **Slack 通知**: Phase 内の `gh issue create` を Slack webhook へ POST するスクリプトに差し替え
- **Email**: cron の `MAILTO` を設定、または systemd の `OnFailure=` にメール送信ユニットを指定
- **Discord / その他**: 同様に webhook へ POST

プロンプト内の `gh issue create` 部分を編集すれば OK です。

## サンプル出力

元プロジェクトの実際のレポート例: https://github.com/dobachi/daily-curation-reports/tree/main/reports/2026/04

こういうアウトプットが欲しい場合はそちらの `config/topics.yml` も参考になります（ただしトピックは元プロジェクトのユーザー固有）。
