# Uninstall Curation Task Scheduler entries (Windows native).

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

foreach ($phase in 1, 2, 3) {
    $taskName = "CurationPhase$phase"
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null
        Write-Host "Removed: $taskName"
    } else {
        Write-Host "Not found: $taskName"
    }
}

Write-Host "Uninstall complete."
