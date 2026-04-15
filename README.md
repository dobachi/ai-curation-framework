# AI Curation Framework

Claude Code を使った **自動キュレーションレポート生成フレームワーク**。自分の興味分野のトピックを定義するだけで、AI が情報収集・執筆・ファクトチェックまで完結した構造化レポートを生成します。

## 特徴

- **3 Phase パイプライン**: リサーチ → 執筆 → ファクトチェックを独立セッションで実行し、自己検証バイアスを排除
- **ソースファースト設計**: 原文引用・クレーム検証マトリクスを必須化し、ハルシネーションを構造的に抑制
- **git ブランチを介した状態受け渡し**: Phase 間は `pipeline/YYYY-MM-DD` ブランチで state を共有
- **柔軟なスケジュール**: systemd timer / cron / Windows Task Scheduler / Claude Code Routine に対応
- **クロスプラットフォーム**: Ubuntu / WSL2 / Windows native のローカル実行をサポート
- **403 対策**: Claude Code の WebFetch で 403 が出る場合、browser UA の Python フェッチャーにフォールバック

## パイプラインの流れ

```
Phase 1 (リサーチ)    → pipeline/YYYY-MM-DD ブランチに research-brief.md
                         （原文引用 + クレーム検証マトリクス）
Phase 2 (執筆)        → 同ブランチに reports/YYYY/MM/DD/*.md
                         （ブリーフのクレームのみを根拠に執筆）
Phase 3 (ファクトチェック + マージ)
                      → 各 URL を WebFetch で再取得して独立検証
                      → PASS なら main に cherry-pick & push
                      → FAIL なら修正 (最大 2 回) → 要レビュー付きでマージ
```

各 Phase は独立したセッションで動くため、Phase 3 は Phase 1・2 の生成過程を知りません（これが自己検証バイアスを防ぎます）。

## クイックスタート

### 1. 2 つのリポジトリを用意

このフレームワークは **パイプライン実装** と **レポート格納** を 1 リポジトリにまとめる形で動きます。

```bash
# A. このフレームワークをテンプレートとしてフォーク or clone
gh repo create my-curation --public --clone --source=. --remote=origin
# もしくは GitHub で fork してから clone

cd my-curation
```

このリポジトリに:
- フレームワークのファイル（`config/`, `scripts/`, `local-runner/`）
- 生成されたレポート（`reports/YYYY/MM/DD/`）
の両方が入ります。

### 2. トピックをカスタマイズ

```bash
cp config/topics.yml.example config/topics.yml
# config/topics.yml を編集（自分が追いたいトピックに書き換え）
```

### 3. ローカル実行環境のセットアップ

対応環境ごとに手順が用意されています:

- **Ubuntu（物理/VM/Raspberry Pi 等）**: [`local-runner/linux/SETUP.md`](local-runner/linux/SETUP.md)
- **WSL2**: [`local-runner/wsl/SETUP.md`](local-runner/wsl/SETUP.md)
- **Windows native**: [`local-runner/windows/SETUP.md`](local-runner/windows/SETUP.md)
- **Claude Code Routine（クラウド）**: [`docs/ROUTINE.md`](docs/ROUTINE.md)

### 4. 手動テスト

```bash
# 環境変数を配置
mkdir -p ~/.config/curation
cp local-runner/env.example ~/.config/curation/runner.env
$EDITOR ~/.config/curation/runner.env

# Phase 1 を手動実行
bash local-runner/run-phase.sh 1
```

`pipeline/YYYY-MM-DD` ブランチが push されれば成功。続けて Phase 2, 3 も手動で動作確認できます。

### 5. 自動実行のスケジュール登録

詳細は各環境の SETUP.md 参照。

## 前提条件

- [Claude Code](https://code.claude.com/docs) CLI（`claude` が認証済み）
- [GitHub CLI](https://cli.github.com/)（`gh` が認証済み）
- Git（push 権限付き、SSH key または PAT）
- Python 3.6+（`scripts/fetch.py` 用。標準ライブラリのみ使用）

## ディレクトリ構成

```
ai-curation-framework/
├── README.md                     # このファイル
├── SETUP.md                      # 詳細なデプロイ手順
├── CUSTOMIZATION.md              # カスタマイズガイド
├── LICENSE                       # MIT
├── config/
│   ├── topics.yml.example        # サンプルトピック
│   └── prompts/
│       ├── phase1.md             # Phase 1: リサーチ指示
│       ├── phase2.md             # Phase 2: 執筆指示
│       └── phase3.md             # Phase 3: ファクトチェック指示
├── scripts/
│   └── fetch.py                  # 403 対策: browser UA で HTTP 取得
├── local-runner/
│   ├── README.md                 # ローカル実行の概要
│   ├── env.example               # 環境変数テンプレ (bash)
│   ├── env.example.ps1           # 環境変数テンプレ (PowerShell)
│   ├── run-phase.sh              # Phase 実行ラッパー (bash)
│   ├── run-phase.ps1             # Phase 実行ラッパー (PowerShell)
│   ├── linux/                    # Ubuntu 向け (cron / systemd)
│   ├── wsl/                      # WSL2 向け (Windows Task Scheduler)
│   └── windows/                  # Windows native 向け
└── reports/                      # 自動生成（最初は空）
    └── YYYY/MM/DD/
        ├── README.md             # 目次
        └── NN-*.md               # 議題ファイル
```

## 設計思想

### なぜ 3 Phase なのか

従来の「1 プロンプトで全部やる」方式にはハルシネーション問題があります。リサーチと同じセッションでファクトチェックをすると、AI は自分の出力を「確認」してしまい、誤りを見逃します。

このフレームワークは Phase 1（リサーチ）と Phase 3（ファクトチェック）を **別セッション** で実行することで、**独立した視点からの検証** を強制します。Phase 3 は Phase 1・2 の生成過程を一切知らず、レポートに記載された URL を再取得して照合するだけです。

### ソースファーストとクレーム検証マトリクス

Phase 1 は以下を必須とします:

- 各ソースから **原文引用**（50-200 文字のコピー）を抽出
- 各クレームを「マトリクス」に整理し、どのソースの原文引用にトレースできるか明示
- 裏付けが 2 ソース以上あるクレームは `DUAL`、1 ソースのみは `SINGLE` と状態表示

Phase 2 はこのマトリクスに存在するクレームのみを根拠に執筆します。AI の一般知識で補う行為は禁止です。

### なぜローカル実行を推奨するか

Anthropic クラウドの IP レンジは CloudFlare 等の bot 検知で 403 を受けやすく、Phase 3 のファクトチェックが機能しにくいことが実測で確認されています。ローカル PC / 常時起動マシンからの実行なら 403 発生率が大幅に下がります。

## カスタマイズ

- **トピック変更**: `config/topics.yml` を編集
- **ツール使用予算**: `config/prompts/phase1.md` の「予算」セクションを調整
- **スケジュール**: `local-runner/` 配下の cron / systemd / Task Scheduler 設定を調整
- **出力言語**: `config/prompts/phase*.md` の「レポート生成」セクションのテンプレート言語を調整（現状は日本語）

詳細は [`CUSTOMIZATION.md`](CUSTOMIZATION.md) 参照。

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) 参照。

## 謝辞

このフレームワークは [Claude Code](https://code.claude.com/) のパイプライン機能を活用しています。設計経緯の詳細は [daily-curation-reports の issue #6](https://github.com/dobachi/daily-curation-reports/issues/6) に記録されています。
