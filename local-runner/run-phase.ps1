# Curation Pipeline - Phase runner (Windows native PowerShell)
#
# Usage: powershell -ExecutionPolicy Bypass -File run-phase.ps1 {1|2|3}
#
# 環境変数ファイル $env:USERPROFILE\.config\curation\runner.env.ps1 を dot source で読み込む。

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet('1','2','3')]
    [string]$Phase
)

$ErrorActionPreference = 'Stop'

# 環境変数ロード
$envFile = $env:CURATION_ENV
if (-not $envFile) {
    $envFile = Join-Path $env:USERPROFILE '.config\curation\runner.env.ps1'
}
if (Test-Path $envFile) {
    . $envFile
}

# デフォルト値
if (-not $env:CURATION_REPO) {
    $env:CURATION_REPO = Join-Path $env:USERPROFILE 'Sources\curation-reports'
}
if (-not $env:CURATION_LOG_DIR) {
    $env:CURATION_LOG_DIR = Join-Path $env:LOCALAPPDATA 'curation\logs'
}
if (-not $env:CURATION_CLAUDE_ARGS) {
    $env:CURATION_CLAUDE_ARGS = '--allowedTools Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch --max-turns 80'
}

# 前提チェック
$required = @('git', 'claude', 'gh')
foreach ($cmd in $required) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "required command not found: $cmd"
        exit 3
    }
}
# Python は py または python3 のどちらかがあればOK
$hasPython = (Get-Command 'py' -ErrorAction SilentlyContinue) -or
             (Get-Command 'python3' -ErrorAction SilentlyContinue) -or
             (Get-Command 'python' -ErrorAction SilentlyContinue)
if (-not $hasPython) {
    Write-Error "required command not found: python (py, python3, or python)"
    exit 3
}

if (-not (Test-Path (Join-Path $env:CURATION_REPO '.git'))) {
    Write-Error "repository not found: $env:CURATION_REPO"
    exit 3
}

# ログ準備
New-Item -ItemType Directory -Force -Path $env:CURATION_LOG_DIR | Out-Null
$date = Get-Date -Format 'yyyy-MM-dd'
$logFile = Join-Path $env:CURATION_LOG_DIR ("phase{0}-{1}.log" -f $Phase, $date)

# ロック（Mutex 的な使い方）
$lockName = "Global\CurationPhase$Phase"
$mutex = New-Object System.Threading.Mutex($false, $lockName)
if (-not $mutex.WaitOne(0)) {
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'o') phase${Phase}: already running, skipping"
    exit 0
}

try {
    Add-Content -Path $logFile -Value ""
    Add-Content -Path $logFile -Value "===== Phase $Phase start: $(Get-Date -Format 'o') ====="

    Set-Location $env:CURATION_REPO

    # 最新取得
    & git fetch origin main 2>&1 | Tee-Object -FilePath $logFile -Append
    & git checkout main 2>&1 | Tee-Object -FilePath $logFile -Append
    & git pull --ff-only origin main 2>&1 | Tee-Object -FilePath $logFile -Append

    # Phase 実行
    $prompt = "config/prompts/phase$Phase.md を読み、その手順に従って Phase $Phase を実行してください。"
    $claudeArgs = $env:CURATION_CLAUDE_ARGS -split ' '
    & claude -p $prompt @claudeArgs 2>&1 | Tee-Object -FilePath $logFile -Append
    $exitCode = $LASTEXITCODE

    Add-Content -Path $logFile -Value "===== Phase $Phase end: $(Get-Date -Format 'o'), exit=$exitCode ====="
    exit $exitCode
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
