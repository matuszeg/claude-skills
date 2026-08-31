# Symlink every skill in this repo into ~/.claude/skills/ so Claude Code
# sessions discover them. Idempotent: re-run any time.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Nested Join-Path: the three-argument form is PowerShell 7+ only, and is a
# positional-parameter error on Windows PowerShell 5.1.
$dest = Join-Path (Join-Path $HOME '.claude') 'skills'
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$linked = 0
foreach ($d in Get-ChildItem -Path $repo -Directory) {
    if (-not (Test-Path (Join-Path $d.FullName 'SKILL.md'))) { continue }
    $target = Join-Path $dest $d.Name
    if (Test-Path $target) {
        $existing = Get-Item $target -Force
        if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            # Delete the link itself. Remove-Item -Force -Recurse on a link can
            # follow it and delete the linked-to contents on PS 5.1 -- which here
            # would be the skill sources in this repo.
            [System.IO.Directory]::Delete($existing.FullName, $false)
        } else {
            Remove-Item $target -Force -Recurse
        }
    }
    # cmd's mklink, not New-Item -ItemType SymbolicLink. Windows PowerShell 5.1
    # runs on .NET Framework, which never passes SYMBOLIC_LINK_FLAG_ALLOW_
    # UNPRIVILEGED_CREATE, so New-Item demands elevation even with Developer Mode
    # enabled. mklink passes the flag and succeeds unelevated.
    cmd /c mklink /D "$target" "$($d.FullName)" | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path $target)) {
        Write-Host "linked $($d.Name) -> $target"
        $linked++
    } else {
        Write-Host @"
ERROR: Could not create symlink for '$($d.Name)'.

Symlinks on Windows need Developer Mode enabled:
  Settings -> Update & Security -> For Developers -> Developer Mode
(or run this script as Administrator)

Then re-run this script.
"@ -ForegroundColor Red
        exit 1
    }
}

if ($linked -eq 0) {
    Write-Host 'no skills found.'
} else {
    Write-Host 'done. new Claude Code sessions will see these skills.'
}
