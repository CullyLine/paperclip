<#
.SYNOPSIS
  Capture the **client area** (not title bar) of a Roblox Studio window to a PNG.
  Use this when you want to **paste the image into Cursor** and ask the AI where the Explorer
  tree is, then set -ExplorerPixelsFromLeft / -ExplorerFracY (or absolute coords) on the copy script.

.PARAMETER ProcessId
  Roblox Studio process ID.

.PARAMETER OutputPath
  Where to save the PNG. Default: %TEMP%\roblox-studio-client-<pid>.png

.EXAMPLE
  .\roblox-studio-capture-client.ps1 -ProcessId 19064
  # Paste the PNG into Cursor: "In this Studio screenshot, give me click coords for the Explorer tree"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int] $ProcessId,

    [string] $OutputPath = ""
)

$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
} catch {
    throw "System.Drawing is required (Windows PowerShell 5.1 includes it). Error: $_"
}

$p = Get-Process -Id $ProcessId -ErrorAction Stop
$h = $p.MainWindowHandle
if ($h -eq [IntPtr]::Zero) {
    throw "Process $ProcessId has no MainWindowHandle."
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $env:TEMP "roblox-studio-client-$ProcessId.png"
}

Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class WinCap {
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);

    public const int SW_RESTORE = 9;
    public const int PW_CLIENTONLY = 0x1;
    public const int PW_RENDERFULLCONTENT = 0x2;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X, Y; }

    /// <summary>
    /// Foregrounds the window, then captures the **client** without needing it to be topmost on screen.
    /// CopyFromScreen alone picks up whatever is drawn on the monitor (e.g. Cursor covering Studio).
    /// </summary>
    public static void CaptureClientToPng(IntPtr hWnd, string path) {
        SetForegroundWindow(hWnd);
        ShowWindow(hWnd, SW_RESTORE);
        System.Threading.Thread.Sleep(450);

        RECT rc;
        if (!GetClientRect(hWnd, out rc)) throw new InvalidOperationException("GetClientRect failed");
        int w = rc.Right - rc.Left;
        int h = rc.Bottom - rc.Top;
        if (w < 10 || h < 10) throw new InvalidOperationException("Client size too small");

        using (var bmp = new Bitmap(w, h)) {
            bool printed = false;
            using (var g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    printed = PrintWindow(hWnd, hdc, PW_CLIENTONLY | PW_RENDERFULLCONTENT);
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            if (!printed) {
                var pt = new POINT { X = 0, Y = 0 };
                if (!ClientToScreen(hWnd, ref pt)) throw new InvalidOperationException("ClientToScreen failed");
                using (var g2 = Graphics.FromImage(bmp)) {
                    g2.CopyFromScreen(pt.X, pt.Y, 0, 0, new Size(w, h));
                }
            }
            bmp.Save(path, ImageFormat.Png);
        }
    }
}
"@ -ReferencedAssemblies @(
    ([System.Reflection.Assembly]::GetAssembly([System.Drawing.Bitmap])).Location
)

[WinCap]::CaptureClientToPng($h, $OutputPath)
Write-Host "Saved: $OutputPath"
Write-Host "Client size captured (pixels). Paste this PNG into Cursor and ask where to click in the Explorer panel."
Write-Host "Then use roblox-studio-copy-paste.ps1 with -ExplorerClientFracX/-ExplorerClientFracY (see roblox-cursor-agent-vision-pipeline.md)."
