<#
.SYNOPSIS
  Bring the Cursor (or VS Code) window to the foreground so you can read the chat after automation.

.EXAMPLE
  .\focus-cursor.ps1
#>
$ErrorActionPreference = 'Stop'

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Foreground {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  public const int SW_RESTORE = 9;
}
"@

$p = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
if (-not $p) {
    $p = Get-Process | Where-Object { $_.MainWindowTitle -match 'Cursor' -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
}
if (-not $p) {
    Write-Host "Cursor window not found (is Cursor running?)." -ForegroundColor Yellow
    exit 1
}

[Foreground]::ShowWindow($p.MainWindowHandle, [Foreground]::SW_RESTORE) | Out-Null
[Foreground]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Write-Host "Focused: $($p.MainWindowTitle) (PID $($p.Id))"
