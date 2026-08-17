# =============================================
#  TaskbarGuard.ps1 — 任务栏守护（完全隐藏 + Win 键唤出）
#  =============================================
#  功能：
#    完全隐藏 Windows 任务栏窗口（比"自动隐藏"更彻底，
#    鼠标移到底部也不会出现），仅当按下 Win 键时临时
#    显示任务栏（配合开始菜单使用），数秒后自动重新隐藏。
#
#  适用：
#    macOS 风格模式下，让任务栏像 macOS 一样不可见，
#    需要时按 Win 键唤出开始菜单/任务栏。
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1        # 前台运行（隐藏+监听）
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Hide  # 仅隐藏后退出
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Show  # 仅显示后退出
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Kill  # 结束后台守护
#
#  原理：
#    ShowWindow(Shell_TrayWnd, SW_HIDE) 完全隐藏任务栏窗口；
#    循环轮询 GetAsyncKeyState(VK_LWIN/VK_RWIN)，检测到 Win 键
#    按下时 ShowWindow(SW_SHOW) 显示任务栏，一段时间后再次隐藏。
# =============================================
param(
    [switch]$Hide,
    [switch]$Show,
    [switch]$Kill
)

$ErrorActionPreference = 'SilentlyContinue'
$guardName = 'TaskbarGuardLoop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TrayGuard {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
'@

$VK_LWIN = 0x5B
$VK_RWIN = 0x5C

function Get-TrayHandle {
    $h = [TrayGuard]::FindWindow('Shell_TrayWnd', $null)
    # 二级任务栏（多显示器）
    $h2 = [TrayGuard]::FindWindow('Shell_SecondaryTrayWnd', $null)
    return @($h, $h2) | Where-Object { $_ -ne [IntPtr]::Zero }
}

function Hide-Taskbar {
    foreach ($h in (Get-TrayHandle)) { [TrayGuard]::ShowWindow($h, 0) | Out-Null }
    Write-Host '[ok] 任务栏已隐藏' -ForegroundColor Green
}

function Show-Taskbar {
    foreach ($h in (Get-TrayHandle)) { [TrayGuard]::ShowWindow($h, 5) | Out-Null }
    Write-Host '[ok] 任务栏已显示' -ForegroundColor Green
}

# ---------- 单次操作模式 ----------
if ($Hide) { Hide-Taskbar; exit 0 }
if ($Show) { Show-Taskbar; exit 0 }

# ---------- Kill 模式：结束已有的守护循环 ----------
if ($Kill) {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'TaskbarGuard' -and $_.CommandLine -notmatch 'Kill' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Write-Host '[ok] 已停止任务栏守护（如需恢复任务栏请运行 -Show）' -ForegroundColor Green
    exit 0
}

# ---------- 守护循环模式（默认） ----------
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  任务栏守护运行中（按 Win 键唤出任务栏）' -ForegroundColor Cyan
Write-Host '  关闭本窗口或运行 -Kill 即可停止' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

Hide-Taskbar

$hiddenSince = Get-Date
$wasPressed = $false

while ($true) {
    $lwin = [TrayGuard]::GetAsyncKeyState($VK_LWIN) -band 0x8000
    $rwin = [TrayGuard]::GetAsyncKeyState($VK_RWIN) -band 0x8000
    $pressed = ($lwin -ne 0) -or ($rwin -ne 0)

    if ($pressed -and -not $wasPressed) {
        # Win 键刚按下：显示任务栏
        foreach ($h in (Get-TrayHandle)) {
            if (-not [TrayGuard]::IsWindowVisible($h)) { [TrayGuard]::ShowWindow($h, 5) | Out-Null }
        }
        $hiddenSince = Get-Date
    }
    $wasPressed = $pressed

    # 如果任务栏可见且 Win 键已松开超过 4 秒，重新隐藏
    if (-not $pressed) {
        foreach ($h in (Get-TrayHandle)) {
            if ([TrayGuard]::IsWindowVisible($h)) {
                $elapsed = (Get-Date) - $hiddenSince
                if ($elapsed.TotalSeconds -gt 4) {
                    [TrayGuard]::ShowWindow($h, 0) | Out-Null
                    $hiddenSince = Get-Date
                }
            }
        }
    }

    Start-Sleep -Milliseconds 200
}
