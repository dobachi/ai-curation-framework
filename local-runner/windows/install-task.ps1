# Install Curation Task Scheduler entries (Windows native).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install-task.ps1
#   powershell -ExecutionPolicy Bypass -File install-task.ps1 -RepoPath "D:\repos\curation-reports"

[CmdletBinding()]
param(
    [string]$RepoPath = ""
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# RepoPath 自動判定（スクリプト位置から2階層上）
if (-not $RepoPath) {
    $RepoPath = Resolve-Path (Join-Path $ScriptDir '..\..') | Select-Object -ExpandProperty Path
    Write-Host "RepoPath auto-detected: $RepoPath"
}

$runnerScript = Join-Path $RepoPath 'local-runner\run-phase.ps1'
if (-not (Test-Path $runnerScript)) {
    Write-Error "run-phase.ps1 not found: $runnerScript"
    exit 1
}

foreach ($phase in 1, 2, 3) {
    $xmlPath = Join-Path $ScriptDir "task-phase$phase.xml"
    if (-not (Test-Path $xmlPath)) {
        Write-Error "XML not found: $xmlPath"
        exit 1
    }

    # プレースホルダ置換（バックスラッシュをエスケープ）
    $xml = Get-Content $xmlPath -Raw -Encoding Unicode
    $xml = $xml.Replace('{{REPO_PATH}}', $RepoPath)

    $tmpPath = Join-Path $env:TEMP "curation-phase$phase.xml"
    [System.IO.File]::WriteAllText($tmpPath, $xml, [System.Text.Encoding]::Unicode)

    $taskName = "CurationPhase$phase"
    # 既存タスクがあれば削除（cmdlet で安全にチェック）
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null
    }

    schtasks.exe /Create /XML $tmpPath /TN $taskName | Out-Null
    Write-Host "Installed: $taskName"

    Remove-Item $tmpPath -Force
}

Write-Host ""
Write-Host "Installation complete. Scheduled tasks:"
Get-ScheduledTask -TaskName "CurationPhase*" | ForEach-Object {
    $info = Get-ScheduledTaskInfo -TaskName $_.TaskName
    Write-Host ("  {0}  NextRun: {1}" -f $_.TaskName, $info.NextRunTime)
}
