# Symlink every skill in this repo into ~/.claude/skills/ so Claude Code
# sessions discover them. Idempotent: re-run any time.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Nested Join-Path: the three-argument form is PowerShell 7+ only, and is a
# positional-parameter error on Windows PowerShell 5.1.
$dest = Join-Path (Join-Path $HOME '.claude') 'skills'
New-Item -ItemType Directory -Path $dest -Force | Out-Null

# Delete a link without following it. Remove-Item -Force -Recurse on a link can
# follow it and delete the linked-to contents on PS 5.1 -- which here would be
# the skill sources in this repo. A junction and a symlink are both reparse
# points, so this covers either kind.
function Remove-Link($path) {
    [System.IO.Directory]::Delete((Get-Item $path -Force).FullName, $false)
}

$linked = 0
foreach ($d in Get-ChildItem -Path $repo -Directory) {
    if (-not (Test-Path (Join-Path $d.FullName 'SKILL.md'))) { continue }
    $target = Join-Path $dest $d.Name
    if (Test-Path $target) {
        $existing = Get-Item $target -Force
        if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Remove-Link $target
        } else {
            Remove-Item $target -Force -Recurse
        }
    }

    # A junction (/J) before a symlink (/D), because a junction needs no
    # privilege at all. A symlink needs Developer Mode or elevation, and on a
    # box with neither -- the default on a fresh Windows install -- every
    # mklink /D fails with "You do not have sufficient privilege", the script
    # links nothing, and Claude Code sees none of these skills. Claude Code
    # follows a junction and a symlink identically, so nothing is given up by
    # preferring the one that always works.
    #
    # A junction does need a local target: handed a UNC path, mklink /J exits 1
    # with "Local volumes are required to complete the operation." So the /D
    # fallback is what reaches a repo kept on a network share or inside a WSL
    # distro, and there the privilege cost is unavoidable.
    #
    # cmd's mklink either way, not New-Item -ItemType SymbolicLink: Windows
    # PowerShell 5.1 runs on .NET Framework, which never passes
    # SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE, so New-Item demands
    # elevation even with Developer Mode enabled. mklink passes the flag and
    # succeeds unelevated.
    #
    # Judge success by reading SKILL.md through the link and nothing else, not
    # by mklink's exit code: mklink will point a junction at a directory that
    # is not there and still exit 0, and Test-Path on such a link returns true
    # because the link itself exists. Reading a file through it is what tells a
    # usable link from a dangling one -- and what hands a failed junction over
    # to /D instead of banking one that cannot be read.
    #
    # The try/catch is load-bearing. $ErrorActionPreference = 'Stop' turns a
    # native command writing to stderr into a TERMINATING error, so the junction
    # failing on a UNC path would kill the script on the spot and /D would never
    # get its turn. Catching it also keeps cmd's complaint off the console, so a
    # first attempt that fails stays quiet when the second one succeeds.
    $ok = $false
    $errors = @()
    foreach ($flag in '/J', '/D') {
        try {
            $out = cmd /c mklink $flag "$target" "$($d.FullName)" 2>&1
        } catch {
            $out = $_.Exception.Message
        }
        if (Test-Path (Join-Path $target 'SKILL.md')) {
            $ok = $true
            break
        }
        $errors += "mklink $flag -> $out"
        if (Test-Path $target) { Remove-Link $target }
    }

    if ($ok) {
        Write-Host "linked $($d.Name) -> $target"
        $linked++
    } else {
        Write-Host @"
ERROR: Could not link '$($d.Name)'.

  $($errors -join "`n  ")

Neither a junction nor a symlink to it resolved. A junction cannot point
outside a local volume, so if this repo is on a network share or inside a WSL
distro, only a symlink will reach it -- and that needs Developer Mode enabled:
  Settings -> Privacy & security -> For developers -> Developer Mode
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
