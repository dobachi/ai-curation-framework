# Windows native セットアップ

Windows 上で **PowerShell + Task Scheduler** でパイプラインを直接実行する方式。WSL を使わないパターン。

## 事前確認

親の [README.md](../README.md) の「前提条件」を先に確認してください。特に以下が Windows で動作することを確認:

- `claude` CLI: `claude --version`
- `git` CLI: `git --version`（Git for Windows 推奨）
- `gh` CLI: `gh --version`
- Python: `py --version` または `python --version`

認証確認:

```powershell
gh auth status
ssh -T git@github.com   # git push 用
```

`claude` CLI は `claude` 初回起動でログインするか、Anthropic コンソールで API key を設定してください。

## セットアップ手順

### 1. リポジトリ clone と環境変数

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\src" | Out-Null
git clone git@github.com:<YOUR_USERNAME>/<YOUR_REPORTS_REPO>.git "$env:USERPROFILE\Sources\curation-reports"
cd $env:USERPROFILE\Sources\curation-reports

# 環境変数ファイル配置
$cfgDir = Join-Path $env:USERPROFILE '.config\curation'
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
Copy-Item local-runner\env.example.ps1 (Join-Path $cfgDir 'runner.env.ps1')
notepad (Join-Path $cfgDir 'runner.env.ps1')
```

### 2. 手動テスト

```powershell
powershell -ExecutionPolicy Bypass -File local-runner\run-phase.ps1 1
```

成功を確認したら次へ。

### 3. Task Scheduler 登録

```powershell
cd $env:USERPROFILE\Sources\curation-reports\local-runner\windows
powershell -ExecutionPolicy Bypass -File install-task.ps1
```

### 4. 登録確認

```powershell
schtasks /Query /TN "CurationPhase1" /FO LIST /V
```

実行時刻:
- CurationPhase1: 毎日 03:30（ローカル時刻）
- CurationPhase2: 毎日 04:30
- CurationPhase3: 毎日 05:30

### 5. 手動実行テスト

```powershell
schtasks /Run /TN "CurationPhase1"
```

### 6. アンインストール

```powershell
powershell -ExecutionPolicy Bypass -File uninstall-task.ps1
```

## ログ

`%LOCALAPPDATA%\curation\logs\phaseN-YYYY-MM-DD.log` に出力されます。

```powershell
Get-ChildItem $env:LOCALAPPDATA\curation\logs
Get-Content $env:LOCALAPPDATA\curation\logs\phase1-*.log | Select-Object -Last 50
```

Task Scheduler 自体のログは Event Viewer → Windows Logs → Microsoft-Windows-TaskScheduler/Operational。

## トラブルシューティング

### PowerShell Execution Policy でブロックされる

`-ExecutionPolicy Bypass` を常に付ける。恒久的に変更するなら:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### タスクがログオン中しか走らない

インストール時のデフォルトは InteractiveToken。ログオフしても走らせたい場合は Windows の資格情報マネージャで対応するか、`-RunWhetherLoggedOn` 版の install スクリプトを使用（要パスワード入力）。

### claude CLI のパスが通らない

`install-task.ps1` は `powershell.exe` を呼ぶだけで、PATH の解決は run-phase.ps1 内部で行う。PowerShell の `$env:PATH` に claude の場所が含まれていない場合、`runner.env.ps1` 内で:

```powershell
$env:Path = "$env:Path;C:\path\to\claude"
```

のように追記する。

### タイムゾーン

Task Scheduler の時刻は Windows のローカル時刻。Windows のタイムゾーン設定を JST にしていない場合、XML 内 `<StartBoundary>` を調整してください。
