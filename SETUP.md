# セットアップガイド

AI Curation Framework を自分の環境にデプロイする詳細手順です。

## 全体像

```
1. リポジトリを fork / clone して自分のものにする
2. config/topics.yml を作成してトピックを定義
3. 実行環境を選ぶ（ローカル / クラウド）
4. 手動テストで pipeline を1回通す
5. スケジューラに登録
```

## Step 1: リポジトリ準備

### GitHub 上で fork or 新規作成

選択肢A: **フォーク**（アップストリームの更新を取り込みやすい）

```bash
# GitHub の Web UI で https://github.com/dobachi/ai-curation-framework を fork
# その後
git clone git@github.com:<YOUR_USERNAME>/ai-curation-framework.git
cd ai-curation-framework
```

選択肢B: **テンプレートから新規作成**（独立したリポジトリ、名前を自由に）

```bash
# テンプレートから作成（Web UI: "Use this template" ボタン）
# または gh CLI で:
gh repo create my-curation \
  --template dobachi/ai-curation-framework \
  --public \
  --clone
cd my-curation
```

### ローカルで clone

どちらの方式でも、**ローカルマシンの home 配下** に clone することを推奨します:

```bash
# 例: ~/Sources 配下に配置（デフォルト想定）
mkdir -p ~/Sources
cd ~/Sources
git clone git@github.com:<YOUR_USERNAME>/<YOUR_REPO>.git curation-reports
# ↑ 第2引数でディレクトリ名を "curation-reports" に指定
# （local-runner のデフォルトパスが $HOME/Sources/curation-reports）
```

別のディレクトリ名にしたい場合は、後述の環境変数 `CURATION_REPO` で上書きできます。

## Step 2: トピック設定

```bash
cd ~/Sources/curation-reports
cp config/topics.yml.example config/topics.yml
```

`config/topics.yml` を編集して、自分が追いたいトピックに書き換えてください。構造はサンプル参照:

- **core**: 毎回必ず扱うメインテーマ（3-5個推奨）
- **domain**: 特定領域（ドメイン）のテーマ（ローテーションで扱う）
- **region**: 地域別テーマ（ローテーション）
- **cross**: 横断テーマ（ローテーション）
- **academic**: 学術研究テーマ（ローテーション）
- **serendipity**: セレンディピティ枠（オプション、意外な接続を狙う）
- **rotation**: 1 回のキュレーションで生成する議題数とカテゴリ配分

## Step 3: 前提コマンドの認証

ローカル実行する環境で、以下がログイン/設定済みであることを確認:

```bash
# Claude Code (CLI)
claude --version
claude login        # 未ログインなら

# GitHub CLI
gh --version
gh auth status      # 未ログインなら gh auth login

# Git push の権限
ssh -T git@github.com     # SSH key で push する場合

# Python
python3 --version   # 3.6+ 必要
```

## Step 4: 環境変数ファイル作成

### Linux / WSL

```bash
mkdir -p ~/.config/curation
cp local-runner/env.example ~/.config/curation/runner.env
nano ~/.config/curation/runner.env   # 好きなエディタで編集
```

### Windows native (PowerShell)

```powershell
$cfgDir = Join-Path $env:USERPROFILE '.config\curation'
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
Copy-Item local-runner\env.example.ps1 (Join-Path $cfgDir 'runner.env.ps1')
notepad (Join-Path $cfgDir 'runner.env.ps1')
```

デフォルト値が自分の環境に合っていればそのままで OK。

## Step 5: 手動テスト

### Linux / WSL

```bash
bash local-runner/run-phase.sh 1
# → pipeline/YYYY-MM-DD ブランチに research-brief.md が push される
```

ログ: `~/.local/share/curation/logs/phase1-YYYY-MM-DD.log`

Phase 2, 3 も順に手動実行して動作確認:

```bash
bash local-runner/run-phase.sh 2
bash local-runner/run-phase.sh 3
```

最終的に main にレポートがマージされれば成功です。

## Step 6: スケジューラ登録

環境別に詳細手順あり:

- **Ubuntu（物理/VM/Raspberry Pi）**: [`local-runner/linux/SETUP.md`](local-runner/linux/SETUP.md)
  - systemd timer（推奨）または cron
- **WSL2**: [`local-runner/wsl/SETUP.md`](local-runner/wsl/SETUP.md)
  - Windows Task Scheduler から wsl.exe 経由で呼ぶ（WSL 停止中でも起動）
- **Windows native**: [`local-runner/windows/SETUP.md`](local-runner/windows/SETUP.md)
  - Windows Task Scheduler + PowerShell
- **Claude Code Routine（クラウド）**: ブラウザで https://claude.ai/code/scheduled から登録

推奨スケジュール（日次運用の例）:

| Phase | JST 時刻 | cron | 備考 |
|---|---|---|---|
| Phase 1 | 03:30 | `30 3 * * *` | リサーチ（所要 5-10 分） |
| Phase 2 | 04:30 | `30 4 * * *` | 執筆（所要 3-5 分） |
| Phase 3 | 05:30 | `30 5 * * *` | ファクトチェック（所要 5-10 分） |

各 Phase に十分なバッファを取ってください。Phase 1 が予想より長く走った場合、Phase 2 が SKIPPED になり翌日にずれる可能性があります。

## Step 7: 運用確認

**翌朝、確認すること**:

```bash
cd ~/Sources/curation-reports
git pull

# 今日のレポートが main に入っているか
ls reports/YYYY/MM/DD/

# ログで何が起きたか
ls ~/.local/share/curation/logs/
tail -50 ~/.local/share/curation/logs/phase3-YYYY-MM-DD.log

# スケジューラの次回実行予定
systemctl --user list-timers | grep curation    # Ubuntu systemd
```

**期待する状態**:
- `reports/YYYY/MM/DD/README.md` が main にある
- ログに `===== Phase N end: ... exit=0 =====` が残っている
- pipeline/YYYY-MM-DD ブランチは削除されている（R3 が自動削除）

**GitHub Issue が作成されていたら**: パイプラインのどこかで失敗しています。Issue の内容と Claude Code セッションログを見て原因調査してください。

## トラブルシューティング

各環境の SETUP.md に個別のトラブルシューティング節があります。それでも解決しない場合は Issue を立ててください（本フレームワークのリポジトリ）。
