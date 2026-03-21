<#
.SYNOPSIS
  Focus Roblox Studio, optionally click the Explorer panel (default), then SendKeys (Ctrl+C / Ctrl+V).
  Default click is the LEFT side of the window (Explorer) so the 3D viewport does not steal selection.
  Clicking the window CENTER selects whatever model/part is under the cursor and breaks MCP Explorer selection.

.PARAMETER SourcePid
  Process ID of the Studio window to COPY from (Ctrl+C).

.PARAMETER TargetPid
  Process ID of the Studio window to PASTE into (Ctrl+V). Omit for same-window copy+paste test.

.PARAMETER Phase
  All (default): click source, Ctrl+C, click target, Ctrl+V. Copy: only source copy. Paste: only target paste
  (use after roblox-studio-copy-verify-loop.ps1 verifies clipboard).

.PARAMETER ClickRegion
  Where to click before SendKeys. Default Explorer — clicks the Explorer tree area, not the viewport.
  (Using a fraction of total width like 12% often still lands in the 3D view on many layouts; defaults
  now use a small pixel offset from the window edge.)

.PARAMETER ExplorerPixelsFromLeft
  When Explorer is docked on the LEFT (default): horizontal position = this many pixels from the
  **left edge of the Studio client area** (inside the Explorer column). Default 28.

.PARAMETER ExplorerOnRight
  Set if your Explorer is docked on the RIGHT. Then -ExplorerPixelsFromRight is used instead.

.PARAMETER ExplorerPixelsFromRight
  When -ExplorerOnRight: click this many pixels left from the **right** edge of the client area.

.PARAMETER ExplorerClientX
  With ExplorerClientY: if both are >= 0, click that **client** pixel (same coords as capture PNG).

.PARAMETER ExplorerClientY
  See ExplorerClientX. Use after roblox-studio-capture-client.ps1 + Cursor/vision to pick a point in Explorer.

.PARAMETER ExplorerClientFracX
.PARAMETER ExplorerClientFracY
  If both are between 0 and 1 (and explicit pixel coords are not set), click at that fraction of the
  **client** width/height. Same for source and target — use after vision on the capture PNG (divide pixel by W/H).

.EXAMPLE
  .\roblox-studio-copy-paste.ps1 -ListStudios

.EXAMPLE
  .\roblox-studio-copy-paste.ps1 -SourcePid 19064 -TargetPid 4184

.EXAMPLE
  # Old behavior (viewport center — only if you intend to copy 3D selection)
  .\roblox-studio-copy-paste.ps1 -SourcePid 19064 -TargetPid 4184 -ClickRegion Viewport

.EXAMPLE
  # Same file: duplicate selection
  .\roblox-studio-copy-paste.ps1 -SourcePid 19064
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int] $SourcePid = 0,

    [Parameter(Mandatory = $false)]
    [int] $TargetPid = 0,

    [switch] $ListStudios,

    [ValidateSet('All', 'Copy', 'Paste')]
    [string] $Phase = 'All',

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

if ($ListStudios) {
    Get-Process | Where-Object { $_.MainWindowTitle -match 'Roblox Studio' } |
        Select-Object Id, MainWindowTitle | Format-Table -AutoSize
    return
}

if (-not $ListStudios) {
    if ($Phase -ne 'Paste' -and $SourcePid -le 0) {
        throw "Usage: -SourcePid <pid> [-TargetPid <pid>] | -ListStudios | -Phase Copy|Paste|All`nExample: .\roblox-studio-copy-paste.ps1 -SourcePid 19064 -TargetPid 4184"
    }
    if (($Phase -eq 'All' -or $Phase -eq 'Paste') -and $TargetPid -le 0) {
        throw "For -Phase All or Paste, -TargetPid is required."
    }
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class StudioClick {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    public const int SW_RESTORE = 9;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X, Y;
    }

    public static void ClickClientCenter(IntPtr hWnd) {
        RECT rc;
        if (!GetClientRect(hWnd, out rc)) {
            throw new InvalidOperationException("GetClientRect failed");
        }
        int cx = (rc.Left + rc.Right) / 2;
        int cy = (rc.Top + rc.Bottom) / 2;
        var pt = new POINT { X = cx, Y = cy };
        if (!ClientToScreen(hWnd, ref pt)) {
            throw new InvalidOperationException("ClientToScreen failed");
        }
        SetCursorPos(pt.X, pt.Y);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    /// <summary>Click inside client area at fraction of width/height (0–1).</summary>
    public static void ClickClientPercent(IntPtr hWnd, double fracX, double fracY) {
        RECT rc;
        if (!GetClientRect(hWnd, out rc)) {
            throw new InvalidOperationException("GetClientRect failed");
        }
        int w = rc.Right - rc.Left;
        int h = rc.Bottom - rc.Top;
        int cx = rc.Left + (int)(w * fracX);
        int cy = rc.Top + (int)(h * fracY);
        var pt = new POINT { X = cx, Y = cy };
        if (!ClientToScreen(hWnd, ref pt)) {
            throw new InvalidOperationException("ClientToScreen failed");
        }
        SetCursorPos(pt.X, pt.Y);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    /// <summary>
    /// Explorer: click a few pixels from the left or right **client** edge so we stay in the tree,
    /// not the viewport. Horizontal is never taken as a fraction of full window width (that misses on many DPI/layouts).
    /// </summary>
    public static void ClickClientExplorer(IntPtr hWnd, bool dockRight, int pixelsFromLeft, int pixelsFromRight, double fracY) {
        RECT rc;
        if (!GetClientRect(hWnd, out rc)) {
            throw new InvalidOperationException("GetClientRect failed");
        }
        int w = rc.Right - rc.Left;
        int h = rc.Bottom - rc.Top;
        int cx;
        if (dockRight) {
            cx = rc.Left + w - pixelsFromRight;
        } else {
            int cap = System.Math.Max(24, w / 5);
            cx = rc.Left + System.Math.Min(pixelsFromLeft, cap);
        }
        int cy = rc.Top + (int)(h * fracY);
        var pt = new POINT { X = cx, Y = cy };
        if (!ClientToScreen(hWnd, ref pt)) {
            throw new InvalidOperationException("ClientToScreen failed");
        }
        SetCursorPos(pt.X, pt.Y);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    /// <summary>Click at client-relative (0,0)=top-left of client. Matches pixels in capture PNG.</summary>
    public static void ClickClientPoint(IntPtr hWnd, int xInClient, int yInClient) {
        RECT rc;
        if (!GetClientRect(hWnd, out rc)) {
            throw new InvalidOperationException("GetClientRect failed");
        }
        int w = rc.Right - rc.Left;
        int h = rc.Bottom - rc.Top;
        int x = System.Math.Max(0, System.Math.Min(w - 1, xInClient));
        int y = System.Math.Max(0, System.Math.Min(h - 1, yInClient));
        var pt = new POINT { X = x, Y = y };
        if (!ClientToScreen(hWnd, ref pt)) {
            throw new InvalidOperationException("ClientToScreen failed");
        }
        SetCursorPos(pt.X, pt.Y);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }
}
"@ -ErrorAction Stop

Add-Type -AssemblyName System.Windows.Forms

function Get-MainWindowHandle {
    param([int] $ProcessId)
    $p = Get-Process -Id $ProcessId -ErrorAction Stop
    if ($p.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "Process $ProcessId has no MainWindowHandle (minimized or no UI?)."
    }
    $p.MainWindowHandle
}

function Invoke-ClickRegion {
    param(
        [IntPtr] $Hwnd,
        [string] $Region,
        [int] $PixelsLeft,
        [double] $FracY,
        [bool] $DockRight,
        [int] $PixelsRight,
        [int] $ExplicitX,
        [int] $ExplicitY,
        [double] $FracClientX,
        [double] $FracClientY
    )
    switch ($Region) {
        'Explorer' {
            if ($ExplicitX -ge 0 -and $ExplicitY -ge 0) {
                [StudioClick]::ClickClientPoint($Hwnd, $ExplicitX, $ExplicitY)
            }
            elseif ($FracClientX -ge 0 -and $FracClientY -ge 0 -and $FracClientX -le 1 -and $FracClientY -le 1) {
                [StudioClick]::ClickClientPercent($Hwnd, $FracClientX, $FracClientY)
            }
            else {
                [StudioClick]::ClickClientExplorer($Hwnd, $DockRight, $PixelsLeft, $PixelsRight, $FracY)
            }
        }
        'Viewport' { [StudioClick]::ClickClientCenter($Hwnd) }
        'None'     { }
    }
}

function Invoke-StudioSourceCopy {
    param(
        [IntPtr] $SourceHwnd,
        [string] $Region,
        [int] $PixelsLeft,
        [double] $FracY,
        [bool] $DockRight,
        [int] $PixelsRight,
        [int] $ExplicitX,
        [int] $ExplicitY,
        [double] $FracClientX,
        [double] $FracClientY,
        [int] $FocusDelayMs,
        [int] $AfterClickDelayMs,
        [int] $AfterCopyDelayMs
    )

    [StudioClick]::ShowWindow($SourceHwnd, [StudioClick]::SW_RESTORE) | Out-Null
    [StudioClick]::SetForegroundWindow($SourceHwnd) | Out-Null
    Start-Sleep -Milliseconds $FocusDelayMs

    Invoke-ClickRegion -Hwnd $SourceHwnd -Region $Region -PixelsLeft $PixelsLeft -FracY $FracY -DockRight $DockRight -PixelsRight $PixelsRight -ExplicitX $ExplicitX -ExplicitY $ExplicitY -FracClientX $FracClientX -FracClientY $FracClientY
    Start-Sleep -Milliseconds $AfterClickDelayMs

    [System.Windows.Forms.SendKeys]::SendWait("^c")
    Write-Host "[source] Ctrl+C sent (click: $Region)."
    Start-Sleep -Milliseconds $AfterCopyDelayMs
}

function Invoke-StudioTargetPaste {
    param(
        [IntPtr] $SourceHwnd,
        [IntPtr] $TargetHwnd,
        [string] $Region,
        [int] $PixelsLeft,
        [double] $FracY,
        [bool] $DockRight,
        [int] $PixelsRight,
        [int] $ExplicitX,
        [int] $ExplicitY,
        [double] $FracClientX,
        [double] $FracClientY,
        [int] $FocusDelayMs,
        [int] $AfterClickDelayMs,
        [int] $AfterPasteDelayMs
    )

    if ($TargetHwnd -ne [IntPtr]::Zero -and $TargetHwnd -ne $SourceHwnd) {
        [StudioClick]::ShowWindow($TargetHwnd, [StudioClick]::SW_RESTORE) | Out-Null
        [StudioClick]::SetForegroundWindow($TargetHwnd) | Out-Null
        Start-Sleep -Milliseconds $FocusDelayMs

        Invoke-ClickRegion -Hwnd $TargetHwnd -Region $Region -PixelsLeft $PixelsLeft -FracY $FracY -DockRight $DockRight -PixelsRight $PixelsRight -ExplicitX $ExplicitX -ExplicitY $ExplicitY -FracClientX $FracClientX -FracClientY $FracClientY
        Start-Sleep -Milliseconds $AfterClickDelayMs

        [System.Windows.Forms.SendKeys]::SendWait("^v")
        Write-Host "[target] Ctrl+V sent (click: $Region)."
        Start-Sleep -Milliseconds $AfterPasteDelayMs
    }
    else {
        [System.Windows.Forms.SendKeys]::SendWait("^v")
        Write-Host "[source] Ctrl+V sent (same window duplicate test)."
        Start-Sleep -Milliseconds $AfterPasteDelayMs
    }
}

function Invoke-StudioCopyPaste {
    param(
        [IntPtr] $SourceHwnd,
        [IntPtr] $TargetHwnd,
        [string] $Region,
        [int] $PixelsLeft,
        [double] $FracY,
        [bool] $DockRight,
        [int] $PixelsRight,
        [int] $ExplicitX,
        [int] $ExplicitY,
        [double] $FracClientX,
        [double] $FracClientY,
        [int] $FocusDelayMs,
        [int] $AfterClickDelayMs,
        [int] $AfterCopyDelayMs,
        [int] $AfterPasteDelayMs
    )

    Invoke-StudioSourceCopy -SourceHwnd $SourceHwnd -Region $Region -PixelsLeft $PixelsLeft -FracY $FracY `
        -DockRight $DockRight -PixelsRight $PixelsRight -ExplicitX $ExplicitX -ExplicitY $ExplicitY `
        -FracClientX $FracClientX -FracClientY $FracClientY -FocusDelayMs $FocusDelayMs `
        -AfterClickDelayMs $AfterClickDelayMs -AfterCopyDelayMs $AfterCopyDelayMs

    Invoke-StudioTargetPaste -SourceHwnd $SourceHwnd -TargetHwnd $TargetHwnd -Region $Region -PixelsLeft $PixelsLeft -FracY $FracY `
        -DockRight $DockRight -PixelsRight $PixelsRight -ExplicitX $ExplicitX -ExplicitY $ExplicitY `
        -FracClientX $FracClientX -FracClientY $FracClientY -FocusDelayMs $FocusDelayMs `
        -AfterClickDelayMs $AfterClickDelayMs -AfterPasteDelayMs $AfterPasteDelayMs
}

$src = if ($Phase -ne 'Paste') { Get-MainWindowHandle -ProcessId $SourcePid } else { [IntPtr]::Zero }
$dst = if (($Phase -eq 'All' -or $Phase -eq 'Paste') -and $TargetPid -gt 0) {
    Get-MainWindowHandle -ProcessId $TargetPid
} else { [IntPtr]::Zero }

Write-Host "Phase: $Phase"
if ($Phase -ne 'Paste') {
    Write-Host "Source PID $SourcePid HWND=$src"
}
if ($ClickRegion -eq 'Explorer') {
    if ($ExplorerClientX -ge 0 -and $ExplorerClientY -ge 0) {
        Write-Host "Explorer click: explicit client pixel ($ExplorerClientX, $ExplorerClientY) - same coords as capture PNG"
    }
    elseif ($ExplorerClientFracX -ge 0 -and $ExplorerClientFracY -ge 0 -and $ExplorerClientFracX -le 1 -and $ExplorerClientFracY -le 1) {
        Write-Host "Explorer click: client fraction ($ExplorerClientFracX, $ExplorerClientFracY) of each window (vision / scaled)"
    }
    elseif ($ExplorerOnRight) {
        Write-Host "Explorer click: ${ExplorerPixelsFromRight}px from RIGHT edge, Y=${ExplorerFracY} of client height"
    }
    else {
        Write-Host "Explorer click: ${ExplorerPixelsFromLeft}px from LEFT edge (capped at 20% width), Y=${ExplorerFracY} of client height"
    }
}
else {
    Write-Host "ClickRegion: $ClickRegion"
}
if ($Phase -ne 'Copy' -and $TargetPid -gt 0) {
    Write-Host "Target PID $TargetPid HWND=$dst"
}
elseif ($Phase -eq 'All' -and $TargetPid -le 0) {
    Write-Host "Target: same window (duplicate test)."
}

$dockRight = $ExplorerOnRight.IsPresent

if ($Phase -eq 'All') {
    Invoke-StudioCopyPaste -SourceHwnd $src -TargetHwnd $dst -Region $ClickRegion `
        -PixelsLeft $ExplorerPixelsFromLeft -FracY $ExplorerFracY -DockRight $dockRight -PixelsRight $ExplorerPixelsFromRight `
        -ExplicitX $ExplorerClientX -ExplicitY $ExplorerClientY -FracClientX $ExplorerClientFracX -FracClientY $ExplorerClientFracY `
        -FocusDelayMs $FocusDelayMs -AfterClickDelayMs $AfterClickDelayMs -AfterCopyDelayMs $AfterCopyDelayMs -AfterPasteDelayMs $AfterPasteDelayMs
}
elseif ($Phase -eq 'Copy') {
    Invoke-StudioSourceCopy -SourceHwnd $src -Region $ClickRegion `
        -PixelsLeft $ExplorerPixelsFromLeft -FracY $ExplorerFracY -DockRight $dockRight -PixelsRight $ExplorerPixelsFromRight `
        -ExplicitX $ExplorerClientX -ExplicitY $ExplorerClientY -FracClientX $ExplorerClientFracX -FracClientY $ExplorerClientFracY `
        -FocusDelayMs $FocusDelayMs -AfterClickDelayMs $AfterClickDelayMs -AfterCopyDelayMs $AfterCopyDelayMs
}
elseif ($Phase -eq 'Paste') {
    Invoke-StudioTargetPaste -SourceHwnd $src -TargetHwnd $dst -Region $ClickRegion `
        -PixelsLeft $ExplorerPixelsFromLeft -FracY $ExplorerFracY -DockRight $dockRight -PixelsRight $ExplorerPixelsFromRight `
        -ExplicitX $ExplorerClientX -ExplicitY $ExplorerClientY -FracClientX $ExplorerClientFracX -FracClientY $ExplorerClientFracY `
        -FocusDelayMs $FocusDelayMs -AfterClickDelayMs $AfterClickDelayMs -AfterPasteDelayMs $AfterPasteDelayMs
}
Write-Host "Done."
