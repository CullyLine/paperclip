<#
.SYNOPSIS
  Focus Roblox Studio and send the shortcut that frames the current selection (default: F).
  Use after MCP execute_luau Selection:Set({...}) or selecting in Explorer.

.PARAMETER ProcessId
  Roblox Studio process ID (use -ListStudios on roblox-studio-copy-paste.ps1).

.PARAMETER Key
  Key to send. Default "f" — Studio's Frame Selection. Use "{F}" for uppercase if needed.

.PARAMETER ClickRegion
  Default Explorer — uses pixels from window edge (same as roblox-studio-copy-paste.ps1), not % of width.

.EXAMPLE
  .\roblox-studio-frame-selection.ps1 -ProcessId 4184
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int] $ProcessId,

    [string] $Key = "f",

    [ValidateSet('Explorer', 'Viewport', 'None')]
    [string] $ClickRegion = 'Explorer',

    [int] $ExplorerPixelsFromLeft = 28,

    [double] $ExplorerFracY = 0.48,

    [switch] $ExplorerOnRight,

    [int] $ExplorerPixelsFromRight = 140,

    [int] $FocusDelayMs = 800,
    [int] $AfterClickDelayMs = 400
)

$ErrorActionPreference = 'Stop'

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
}
"@ -ErrorAction Stop

Add-Type -AssemblyName System.Windows.Forms

$p = Get-Process -Id $ProcessId -ErrorAction Stop
$h = $p.MainWindowHandle
if ($h -eq [IntPtr]::Zero) {
    throw "Process $ProcessId has no MainWindowHandle."
}

[StudioClick]::ShowWindow($h, [StudioClick]::SW_RESTORE) | Out-Null
[StudioClick]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds $FocusDelayMs

$dockRight = $ExplorerOnRight.IsPresent
switch ($ClickRegion) {
    'Explorer' { [StudioClick]::ClickClientExplorer($h, $dockRight, $ExplorerPixelsFromLeft, $ExplorerPixelsFromRight, $ExplorerFracY) }
    'Viewport' { [StudioClick]::ClickClientCenter($h) }
    'None'     { }
}
Start-Sleep -Milliseconds $AfterClickDelayMs

[System.Windows.Forms.SendKeys]::SendWait($Key)
Write-Host "Sent key: $Key to PID $ProcessId (click: $ClickRegion)."
Write-Host "Done."
