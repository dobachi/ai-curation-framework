# Install Curation Task Scheduler entries for WSL2.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install-task.ps1
#   powershell -ExecutionPolicy Bypass -File install-task.ps1 -WslDistro "Ubuntu-22.04" -WslUser "myuser"

[CmdletBinding()]
param(
    [string]$WslDistro = "",
    [string]$WslUser = ""
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# wsl.exe の出力を UTF-8 で受け取る（デフォルト UTF-16 LE を Shift-JIS 誤読させない）
$env:WSL_UTF8 = 1
$prevOutputEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    # WSL ディストロ自動判定:
    # 1. スクリプトが \\wsl.localhost\<distro>\... または \\wsl$\<distro>\... 経由で呼ばれていれば、そこから取得
    # 2. 取れなければ wsl --status の Default Distribution を使う（日本語版は "既定のディストリビューション:"）
    if (-not $WslDistro) {
        if ($ScriptDir -match '^\\\\wsl(?:\.localhost|\$)\\([^\\]+)\\') {
            $WslDistro = $matches[1]
            Write-Host "WSL distro auto-detected (from script path): $WslDistro"
        } else {
            $statusOutput = wsl.exe --status 2>$null | Out-String
            if ($statusOutput -match '(?:Default Distribution|既定のディストリビューション):\s*(\S+)') {
                $WslDistro = $matches[1].Trim()
                Write-Host "WSL distro auto-detected (default): $WslDistro"
            } else {
                Write-Error "Cannot detect WSL distro. Specify -WslDistro (e.g., 'Ubuntu-22.04')."
                exit 1
            }
        }
    }

    # WSL ユーザー自動判定: 指定ディストロで whoami
    if (-not $WslUser) {
        $WslUser = (wsl.exe -d $WslDistro whoami 2>$null | Out-String).Trim()
        if (-not $WslUser -or $WslUser -match '[^\x20-\x7e]') {
            Write-Error "Cannot detect WSL user cleanly (got: '$WslUser'). Specify -WslUser."
            exit 1
        }
        Write-Host "WSL user auto-detected: $WslUser"
    }
}
finally {
    [Console]::OutputEncoding = $prevOutputEncoding
}

# 各 Phase の XML を処理
foreach ($phase in 1, 2, 3) {
    $xmlPath = Join-Path $ScriptDir "task-phase$phase.xml"
    if (-not (Test-Path $xmlPath)) {
        Write-Error "XML not found: $xmlPath"
        exit 1
    }

    # テンプレートを読み込み、プレースホルダ置換
    $xml = Get-Content $xmlPath -Raw -Encoding Unicode
    $xml = $xml.Replace('{{WSL_DISTRO}}', $WslDistro)
    $xml = $xml.Replace('{{WSL_USER}}', $WslUser)

    # 一時ファイルに保存（UTF-16 LE with BOM が Task Scheduler の要求）
    $tmpPath = Join-Path $env:TEMP "curation-phase$phase.xml"
    [System.IO.File]::WriteAllText($tmpPath, $xml, [System.Text.Encoding]::Unicode)

    # 既存タスクがあれば削除（cmdlet 経由で安全にチェック）
    $taskName = "CurationPhase$phase"
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null
    }

    # 登録
    schtasks.exe /Create /XML $tmpPath /TN $taskName | Out-Null
    $hour = 2 + $phase  # Phase1=03, Phase2=04, Phase3=05
    Write-Host ("Installed: {0} (daily at {1:D2}:30)" -f $taskName, $hour)

    Remove-Item $tmpPath -Force
}

Write-Host ""
Write-Host "Installation complete. Scheduled tasks:"
Get-ScheduledTask -TaskName "CurationPhase*" | ForEach-Object {
    $info = Get-ScheduledTaskInfo -TaskName $_.TaskName
    Write-Host ("  {0}  NextRun: {1}" -f $_.TaskName, $info.NextRunTime)
}
