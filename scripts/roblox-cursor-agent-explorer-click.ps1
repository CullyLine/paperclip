<#
.SYNOPSIS
  Capture Roblox Studio client to a **fixed path in this repo** so the **Cursor agent** can
  `read_file` the PNG, **see** where Explorer is, then run `roblox-studio-copy-paste.ps1` with
  `-ExplorerClientX` / `-ExplorerClientY`.

  This is the missing piece: the agent reads the screenshot (vision), you do not paste coords by hand.

.PARAMETER ProcessId
  Roblox Studio PID to capture (usually the SOURCE place you are copying from).

.PARAMETER OutputPath
  Default: scripts/.tmp/studio-client-latest.png (next to this script).

.EXAMPLE
  .\roblox-cursor-agent-explorer-click.ps1 -ProcessId 19064
  # Then in Cursor: ask the agent to read scripts/.tmp/studio-client-latest.png and run copy-paste with coords.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int] $ProcessId,

    [string] $OutputPath = ""
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutputPath) {
    $OutputPath = Join-Path $here ".tmp\studio-client-latest.png"
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

& (Join-Path $here "roblox-studio-capture-client.ps1") -ProcessId $ProcessId -OutputPath $OutputPath

Write-Host ""
Write-Host "=== CURSOR AGENT ===" -ForegroundColor Cyan
Write-Host "Read this file with the Read tool (image):"
Write-Host $OutputPath
Write-Host "Then run roblox-studio-copy-paste.ps1 with -ExplorerClientX and -ExplorerClientY from your analysis."
Write-Host "====================" -ForegroundColor Cyan
