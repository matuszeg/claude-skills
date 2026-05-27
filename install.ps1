# Symlink every skill in this repo into ~/.claude/skills/ so Claude Code
# sessions discover them. Idempotent: re-run any time.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Definition
$dest = Join-Path $HOME '.claude' 'skills'
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$linked = 0
foreach ($d in Get-ChildItem -Path $repo -Directory) {
    if (-not (Test-Path (Join-Path $d.FullName 'SKILL.md'))) { continue }
    $target = Join-Path $dest $d.Name
    if (Test-Path $target) { Remove-Item $target -Force -Recurse }
    try {
        New-Item -ItemType SymbolicLink -Path $target -Target $d.FullName | Out-Null
        Write-Host "linked $($d.Name) -> $target"
        $linked++
    } catch {
        Write-Host @"
ERROR: Could not create symlink for '$($d.Name)'.

Creating symlinks on Windows requires one of:
  1. Run this script as Administrator (right-click PowerShell -> Run as Administrator)
  2. Enable Developer Mode: Settings -> Update & Security -> For Developers -> Developer Mode

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
