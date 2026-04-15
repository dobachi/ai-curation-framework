# Curation Local Runner - Environment Variables (PowerShell)
#
# コピー先: $env:USERPROFILE\.config\curation\runner.env.ps1
# 使い方:
#   $dir = Join-Path $env:USERPROFILE '.config\curation'
#   New-Item -ItemType Directory -Force -Path $dir | Out-Null
#   Copy-Item local-runner\env.example.ps1 (Join-Path $dir 'runner.env.ps1')
#   # このファイルを編集

# リポジトリのローカルパス（必須）
$env:CURATION_REPO = Join-Path $env:USERPROFILE 'Sources\curation-reports'

# ログディレクトリ
$env:CURATION_LOG_DIR = Join-Path $env:LOCALAPPDATA 'curation\logs'

# claude CLI の追加引数
# --allowedTools でツール許可を事前付与（非対話実行のため必須）
$env:CURATION_CLAUDE_ARGS = '--allowedTools Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch --max-turns 80'
