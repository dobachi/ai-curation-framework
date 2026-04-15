# Local Runner — Curation Pipeline

ローカル PC / 常時起動マシンで 3 Phase パイプラインを動かす仕組みです。**運用はローカル優先、Claude Code Routine（クラウド）は fallback** として並行稼働させます。

## なぜローカル実行が主になるのか

Anthropic クラウドの IP レンジは CloudFlare 等の bot 検知で 403 ブロックされるため、Phase 3 の WebFetch ベースのファクトチェックが実質機能しません。ローカル PC / 常時起動マシンの IP なら 403 発生率が大幅に下がります。

### 実測（2026-04-15）

同じ日に 10 URL をクラウドとローカルで取得した結果:

| 環境 | HTTP 200 率 | ファクトチェック判定 |
|---|---|---|
| クラウド Routine | 0/10（全 403） | 10/10 Unverifiable（形式的 PASS） |
| ローカル実行 | ほぼ 10/10 | 33/34 Verified, 1 Mostly Accurate（真の PASS） |

クラウドだけでは「ソース再取得で独立検証」という設計が機能せず、ハルシネーションを見逃すリスクがあります。

## 並行運用の仕組み

```
常時起動マシン（ローカル）: 03:30 → 04:30 → 05:30 JST
Anthropic クラウド Routine: 04:00 → 05:00 → 06:00 JST
```

- ローカルが先に動き、成果物（`pipeline/YYYY-MM-DD` ブランチ、`reports/YYYY/MM/DD/`）を生成
- 30 分後に動くクラウド側は既存の冪等性チェックで SKIPPED になる
- ローカルが失敗した場合、クラウドが fallback として動く
- 追加の調整ロジック不要

## 対応環境

| 環境 | スケジューラ | ラッパー | セットアップ |
|---|---|---|---|
| Ubuntu（物理/VM） | systemd timer（推奨）/ cron | `run-phase.sh` | [linux/SETUP.md](linux/SETUP.md) |
| WSL2 | Windows Task Scheduler → `wsl.exe` | `run-phase.sh`（WSL 内） | [wsl/SETUP.md](wsl/SETUP.md) |
| Windows native | Windows Task Scheduler | `run-phase.ps1` | [windows/SETUP.md](windows/SETUP.md) |

## 前提条件

すべての環境で以下が必要:

- **`git`** 認証済み（SSH key または PAT で push 可能）
- **`claude` CLI** ログイン済み（`claude login` または `claude setup-token`）
- **`gh` CLI** ログイン済み（`gh auth status` で確認）
- **Python 3.6+**（`scripts/fetch.py` 用。Linux は `python3`、Windows は `py` または `python`）

## クイックスタート

### 1. リポジトリを clone

```bash
# Linux/WSL
git clone git@github.com:<YOUR_USERNAME>/<YOUR_REPORTS_REPO>.git ~/Sources/curation-reports
```

```powershell
# Windows native
git clone git@github.com:<YOUR_USERNAME>/<YOUR_REPORTS_REPO>.git $env:USERPROFILE\Sources\curation-reports
```

### 2. 環境変数ファイルを配置

```bash
# Linux/WSL
mkdir -p ~/.config/curation
cp local-runner/env.example ~/.config/curation/runner.env
$EDITOR ~/.config/curation/runner.env
```

```powershell
# Windows native
$dir = Join-Path $env:USERPROFILE '.config\curation'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item local-runner\env.example.ps1 (Join-Path $dir 'runner.env.ps1')
notepad (Join-Path $dir 'runner.env.ps1')
```

### 3. 手動テスト

```bash
# Linux/WSL
bash local-runner/run-phase.sh 1
```

```powershell
# Windows native
powershell -ExecutionPolicy Bypass -File local-runner\run-phase.ps1 1
```

Phase 1 が成功すると `pipeline/YYYY-MM-DD` ブランチが push されます。

### 4. 環境別の詳細セットアップ

- **Ubuntu**: [linux/SETUP.md](linux/SETUP.md)
- **WSL2**: [wsl/SETUP.md](wsl/SETUP.md)
- **Windows native**: [windows/SETUP.md](windows/SETUP.md)

## トラブルシューティング

### ログの場所

- **Linux/WSL**: `~/.local/share/curation/logs/phaseN-YYYY-MM-DD.log`
- **Windows native**: `%LOCALAPPDATA%\curation\logs\phaseN-YYYY-MM-DD.log`
- **systemd**: `journalctl --user -u curation-phase1 -b`
- **Task Scheduler**: Windows Event Viewer > Microsoft > Windows > TaskScheduler

### claude 認証が切れている

```bash
claude login
```

### gh 認証確認

```bash
gh auth status
# 未ログインなら:
gh auth login
```

### git push が失敗する（SSH）

```bash
ssh -T git@github.com
# Permission denied なら ssh-add または ~/.ssh/config を確認
```

### 一時的に停止したい

**cron**: `crontab -e` で該当行をコメントアウト
**systemd**: `systemctl --user stop curation-phase1.timer` + `disable`
**Task Scheduler**: タスクスケジューラで「無効」に変更

### 冪等性を確認したい

同じ日の Phase 1 を 2 回実行してみる:
```bash
bash local-runner/run-phase.sh 1  # 1回目: brief を生成して commit
bash local-runner/run-phase.sh 1  # 2回目: "SKIPPED" で終了、何もコミットされない
```

## アーキテクチャ

- 各 Phase は `config/prompts/phase{1,2,3}.md` を参照（クラウド Routine と共通）
- WebFetch 403 時は `scripts/fetch.py` にフォールバック（browser UA）
- Phase 間の状態受け渡しは `pipeline/YYYY-MM-DD` git ブランチ経由
- Phase 3 で `main` に cherry-pick

詳細は [issue #6](https://github.com/<YOUR_USERNAME>/<YOUR_REPORTS_REPO>/issues/6) 参照。
