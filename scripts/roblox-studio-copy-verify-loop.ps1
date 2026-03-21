<#
.SYNOPSIS
  Copy from source Studio, READ the Windows clipboard, retry up to N times, then paste into target.

  CRITICAL: If you already set selection with MCP (Selection:Set), an Explorer click BEFORE Ctrl+C will
  SELECT WHATEVER ROW IS UNDER THE MOUSE - usually NOT your folder. Use -SkipExplorerClick so we only
  foreground the window and send Ctrl+C/Ctrl+V (selection stays what MCP set).

.PARAMETER SkipExplorerClick
  Do not click before SendKeys. Use this whenever selection was set via MCP execute_luau. Default is OFF
  for legacy scripts that relied on Explorer click to steal focus from the viewport.

.PARAMETER MaxAttempts
  Default 3.

.PARAMETER ExpectedClipboardSubstring
  If set, at least one text format on the clipboard must contain this (case-insensitive).

.PARAMETER AllowOpaqueClipboard
  Default ON: if there is no matching text but the clipboard has **any** formats, treat as OK (Roblox binary).

.PARAMETER DisallowOpaqueClipboard
  Turn off AllowOpaqueClipboard — require text formats only (stricter; often fails with Roblox).

  Remaining parameters are forwarded to roblox-studio-copy-paste.ps1 (same Explorer / PID options).

.EXAMPLE
  # After MCP Selection:Set - use SkipExplorerClick (recommended)
  .\roblox-studio-copy-verify-loop.ps1 -SourcePid 19064 -TargetPid 4184 -SkipExplorerClick

.EXAMPLE
  .\roblox-studio-copy-verify-loop.ps1 -SourcePid 19064 -TargetPid 4184 -ExplorerClientFracX 0.82 -ExplorerClientFracY 0.30
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int] $SourcePid,

    [Parameter(Mandatory = $true)]
    [int] $TargetPid,

    [int] $MaxAttempts = 3,

    [string] $ExpectedClipboardSubstring = "",

    [switch] $DisallowOpaqueClipboard,

    [switch] $SkipExplorerClick,

    [ValidateSet('Explorer', 'Viewport', 'None')]
    [string] $ClickRegion = 'Explorer',

    [int] $ExplorerPixelsFromLeft = 28,

    [double] $ExplorerFracY = 0.48,

    [switch] $ExplorerOnRight,

    [int] $ExplorerPixelsFromRight = 140,

    [int] $ExplorerClientX = -1,

    [int] $ExplorerClientY = -1,

    [double] $ExplorerClientFracX = -1,

    [double] $ExplorerClientFracY = -1,

    [int] $FocusDelayMs = 800,
    [int] $AfterClickDelayMs = 400,
    [int] $AfterCopyDelayMs = 2000,
    [int] $AfterPasteDelayMs = 500
)

$ErrorActionPreference = 'Stop'

$AllowOpaqueClipboard = -not $DisallowOpaqueClipboard.IsPresent

function Test-RobloxClipboardVerify {
    param(
        [string] $ExpectedSubstring,
        [bool] $AllowOpaque
    )
    Add-Type -AssemblyName System.Windows.Forms
    $o = [System.Windows.Forms.Clipboard]::GetDataObject()
    if (-not $o) {
        return @{ Ok = $false; Detail = 'Clipboard has no DataObject' }
    }
    $formats = @($o.GetFormats())
    if ($formats.Count -eq 0) {
        return @{ Ok = $false; Detail = 'Clipboard has zero formats' }
    }

    $allText = [System.Text.StringBuilder]::new()
    foreach ($f in $formats) {
        try {
            $d = $o.GetData($f, $false)
            if ($null -eq $d) { continue }
            if ($d -is [string] -and $d.Length -gt 0) {
                [void]$allText.AppendLine("[$f] " + $d)
            }
        } catch {}
    }
    $text = $allText.ToString()

    if ($ExpectedSubstring -ne '') {
        $tl = $text.ToLowerInvariant()
        $el = $ExpectedSubstring.ToLowerInvariant()
        if ($tl.Contains($el)) {
            return @{ Ok = $true; Detail = 'Expected substring found in text clipboard'; Formats = $formats; TextPreview = $text.Substring(0, [Math]::Min(400, $text.Length)) }
        }
        return @{ Ok = $false; Detail = "Expected substring not found: $ExpectedSubstring"; Formats = $formats; TextPreview = $text.Substring(0, [Math]::Min(400, $text.Length)) }
    }

    if ($text.Trim().Length -gt 0) {
        return @{ Ok = $true; Detail = 'Non-empty text on clipboard'; Formats = $formats; TextPreview = $text.Substring(0, [Math]::Min(400, $text.Length)) }
    }

    if ($AllowOpaque) {
        return @{ Ok = $true; Detail = 'Opaque clipboard only (formats present, no plain text - typical for Roblox instances)'; Formats = $formats }
    }

    return @{ Ok = $false; Detail = 'No text and opaque clipboard not allowed'; Formats = $formats }
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$copyPaste = Join-Path $here "roblox-studio-copy-paste.ps1"

$dockRight = $ExplorerOnRight.IsPresent

if ($SkipExplorerClick) {
    $ClickRegion = 'None'
}

$commonArgs = @{
    SourcePid            = $SourcePid
    TargetPid            = $TargetPid
    ClickRegion          = $ClickRegion
    ExplorerPixelsFromLeft = $ExplorerPixelsFromLeft
    ExplorerFracY        = $ExplorerFracY
    ExplorerPixelsFromRight = $ExplorerPixelsFromRight
    ExplorerClientX      = $ExplorerClientX
    ExplorerClientY      = $ExplorerClientY
    ExplorerClientFracX  = $ExplorerClientFracX
    ExplorerClientFracY  = $ExplorerClientFracY
    FocusDelayMs         = $FocusDelayMs
    AfterClickDelayMs    = $AfterClickDelayMs
    AfterCopyDelayMs     = $AfterCopyDelayMs
    AfterPasteDelayMs    = $AfterPasteDelayMs
}
if ($ExplorerOnRight) {
    $commonArgs['ExplorerOnRight'] = $true
}

if ($SkipExplorerClick) {
    Write-Host "SkipExplorerClick: ClickRegion=None (MCP selection will NOT be overwritten by a fake Explorer click)" -ForegroundColor Cyan
}

$ok = $false
$lastDetail = ""

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Write-Host ""
    Write-Host "=== Copy attempt $attempt / $MaxAttempts ===" -ForegroundColor Cyan

    & $copyPaste @commonArgs -Phase Copy

    Start-Sleep -Milliseconds 300
    $v = Test-RobloxClipboardVerify -ExpectedSubstring $ExpectedClipboardSubstring -AllowOpaque $AllowOpaqueClipboard

    Write-Host "Clipboard check: $($v.Detail)"
    if ($v.Formats) {
        Write-Host "Formats: $($v.Formats -join ', ')"
    }
    if ($v.TextPreview) {
        Write-Host "Text preview: $($v.TextPreview)"
    }

    if ($v.Ok) {
        $ok = $true
        $lastDetail = $v.Detail
        break
    }
    $lastDetail = $v.Detail
    Write-Host "Verify failed - retrying if attempts remain..." -ForegroundColor Yellow
}

if (-not $ok) {
    Write-Host ""
    Write-Host "ABORT: Clipboard did not verify after $MaxAttempts attempts. Last: $lastDetail" -ForegroundColor Red
    Write-Host "Tip: run MCP execute_luau with scripts/verify-selection.luau to confirm Explorer selection."
    exit 1
}

Write-Host ""
Write-Host "Clipboard OK ($lastDetail). Pasting to target..." -ForegroundColor Green
& $copyPaste @commonArgs -Phase Paste
Write-Host "Done."
