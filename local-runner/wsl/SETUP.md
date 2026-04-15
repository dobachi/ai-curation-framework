# WSL2 セットアップ

Windows の **Task Scheduler** から `wsl.exe` 経由で WSL 内の `run-phase.sh` を呼ぶ方式。WSL が停止していても Task Scheduler が発火すれば WSL が自動起動してジョブが走ります。

**リポジトリは WSL 内にのみ clone します**（Windows 側には clone 不要）。Task Scheduler への登録処理 `install-task.ps1` は Windows の PowerShell から UNC パス（`\\wsl.localhost\<distro>\...`）で WSL 内のスクリプトを呼び出して実行します。

## 事前確認

親の [README.md](../README.md) の「前提条件」を先に確認してください:

- WSL 側で `claude`, `git`, `gh`, `python3` が認証・動作確認済み
- Windows のディストロ名を確認: PowerShell で `wsl.exe -l -v`
- WSL のユーザー名を確認: WSL 内で `whoami`

## セットアップ手順

### 1. WSL 内でリポジトリと環境変数を準備

WSL ターミナルで実施:

```bash
git clone git@github.com:<YOUR_USERNAME>/<YOUR_REPORTS_REPO>.git ~/Sources/curation-reports
cd ~/Sources/curation-reports

mkdir -p ~/.config/curation
cp local-runner/env.example ~/.config/curation/runner.env
$EDITOR ~/.config/curation/runner.env
```

### 2. 手動テスト（WSL 内で）

```bash
bash local-runner/run-phase.sh 1
```

成功を確認したら次へ。

### 3. Windows Task Scheduler 登録

Windows の PowerShell を **通常ユーザー権限**で開き、以下を実行:

```powershell
powershell -ExecutionPolicy Bypass -File "\\wsl.localhost\<DISTRO>\home\<WSL_USER>\Sources\curation-reports\local-runner\wsl\install-task.ps1"
```

`<DISTRO>`（例: `Ubuntu-22.04`）と `<WSL_USER>`（例: `<YOUR_USER>`）は自分の環境に置き換えてください。

**install-task.ps1 の自動検出**:
- **WSL ディストロ**: UNC パス（上記 `\\wsl.localhost\<DISTRO>\...`）からディストロ名を抽出
- **WSL ユーザー**: そのディストロで `wsl.exe whoami` を実行して取得

したがって、UNC パスさえ正しければ引数なしで動きます。複数ディストロがあっても UNC パスのものが使われます。

**明示指定したい場合**（例: 自動検出が失敗する場合）:
```powershell
powershell -ExecutionPolicy Bypass -File "\\wsl.localhost\Ubuntu-22.04\home\<YOUR_USER>\Sources\curation-reports\local-runner\wsl\install-task.ps1" -WslDistro "Ubuntu-22.04" -WslUser "<YOUR_USER>"
```

### 4. 登録確認

```powershell
Get-ScheduledTask -TaskName "CurationPhase*" | Get-ScheduledTaskInfo
```

実行時刻:
- CurationPhase1: 毎日 03:30（ローカル時刻）
- CurationPhase2: 毎日 04:30
- CurationPhase3: 毎日 05:30

### 5. 手動実行テスト

```powershell
Start-ScheduledTask -TaskName "CurationPhase1"
```

Task Scheduler UI（`taskschd.msc`）でも「実行」→「最新の結果」で確認可能。

### 6. アンインストール

```powershell
powershell -ExecutionPolicy Bypass -File "\\wsl.localhost\<DISTRO>\home\<WSL_USER>\Sources\curation-reports\local-runner\wsl\uninstall-task.ps1"
```

## ログ

ログは **WSL 内** のパスに出力されます:

```bash
# WSL 内で確認
ls ~/.local/share/curation/logs/
tail -f ~/.local/share/curation/logs/phase1-$(date +%Y-%m-%d).log
```

Task Scheduler 自体の実行履歴は Windows Event Viewer > Microsoft > Windows > TaskScheduler、または `taskschd.msc` の「履歴」タブで確認可能。

## トラブルシューティング

### UNC パスが見つからない

```
-File パラメーターの引数 '...\install-task.ps1' は存在しません
```

主な原因:
- **WSL が停止している** → PowerShell で `wsl` を叩いて起動しておく
- **ディストロ名が間違っている** → `wsl.exe -l -v` で確認（`Ubuntu-22.04` のように完全名を使う）
- **Windows 10 の古い版** → `\\wsl$\<distro>\...` の書式を試す（Windows 11 は `\\wsl.localhost\...` が標準）

### "Logon failure" / タスクが走らない

Task Scheduler のトリガーは「ログオン中のみ」がデフォルト（`install-task.ps1` の設定）。常時実行したい場合は Task Scheduler UI で該当タスクを開き、「全般」タブで「ユーザーがログオンしているかどうかにかかわらず実行する」を選択してください（パスワード入力が必要）。

### 文字化け / 自動検出が不正な値になる

`wsl.exe` の出力がデフォルト UTF-16 LE でエンコード差異が出る環境がある場合、`install-task.ps1` は `WSL_UTF8=1` と `[Console]::OutputEncoding=UTF8` を設定して対処しています。それでも不具合が出る場合は `-WslDistro` と `-WslUser` を明示指定してください。

### 手動で wsl.exe のコマンドを試す

```powershell
wsl.exe -d Ubuntu-22.04 -u <YOUR_USER> bash -lic "~/Sources/curation-reports/local-runner/run-phase.sh 1"
```

`-lic` で login shell + interactive（PATH が通る）。

## タイムゾーンの注意

Task Scheduler の時刻は **Windows のローカル時刻**。Windows のタイムゾーンが JST でない場合、XML 内の時刻を調整するか、Windows のタイムゾーンを確認してください。
