# =============================================
#  TaskbarGuard.ps1 — 任务栏守护 v6（绝对隐藏 + Win 键唤出）
#  =============================================
#  行为（严格符合需求）：
#    - 平时：任务栏【绝对隐藏】——鼠标移到底部、软件退出、
#      窗口切换、explorer 刷新，任何情况都不会出现
#    - 按【一下】Win 键：任务栏出现（开始菜单弹出）
#    - 唤出后任务栏保持可用；开始菜单关闭后自动重新隐藏
#
#  可靠性（v6）：
#    - 注册表 StuckRects3 固定为 02（常驻），杜绝系统
#      "自动隐藏"逻辑导致鼠标悬停滑出任务栏
#    - 双保险：即使守护异常，常驻模式下任务栏也不会自己出现
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1        # 前台运行（守护）
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Hide  # 仅隐藏后退出
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Show  # 仅显示后退出
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Kill  # 结束后台守护
# =============================================
param(
    [switch]$Hide,
    [switch]$Show,
    [switch]$Kill
)

$ErrorActionPreference = 'SilentlyContinue'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TrayGuardV6 {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
'@

$VK_LWIN = 0x5B
$VK_RWIN = 0x5C

function Get-TrayHandles {
    $hs = @()
    foreach ($cls in @('Shell_TrayWnd', 'Shell_SecondaryTrayWnd')) {
        $h = [TrayGuardV6]::FindWindow($cls, $null)
        if ($h -ne [IntPtr]::Zero) { $hs += $h }
    }
    return $hs
}

function Hide-Taskbar {
    foreach ($h in (Get-TrayHandles)) {
        if ([TrayGuardV6]::IsWindowVisible($h)) { [TrayGuardV6]::ShowWindow($h, 0) | Out-Null }
    }
}

function Show-Taskbar {
    foreach ($h in (Get-TrayHandles)) {
        if (-not [TrayGuardV6]::IsWindowVisible($h)) { [TrayGuardV6]::ShowWindow($h, 5) | Out-Null }
    }
}

function Test-StartMenuVisible {
    $sm = Get-Process -Name 'StartMenuExperienceHost' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sm -and $sm.MainWindowHandle -ne 0) {
        return [TrayGuardV6]::IsWindowVisible($sm.MainWindowHandle)
    }
    return $false
}

function Ensure-NormalTaskbarMode {
    # 固定 StuckRects3=02（常驻），杜绝系统自动隐藏导致的鼠标悬停滑出
    try {
        $regStuck = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
        $sr = (Get-ItemProperty $regStuck -Name Settings -ErrorAction SilentlyContinue).Settings
        if ($sr -and $sr.Length -gt 8 -and $sr[8] -ne 2) {
            $sr[8] = 2
            Set-ItemProperty $regStuck -Name Settings -Value $sr -Type Binary
        }
    } catch { }
}

# ---------- 单次操作模式 ----------
if ($Hide) { Hide-Taskbar; Write-Host '[ok] 任务栏已隐藏' -ForegroundColor Green; exit 0 }
if ($Show) { Show-Taskbar; Write-Host '[ok] 任务栏已显示' -ForegroundColor Green; exit 0 }

# ---------- Kill 模式 ----------
if ($Kill) {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'TaskbarGuard' -and $_.CommandLine -notmatch 'Kill' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Write-Host '[ok] 已停止任务栏守护（如需恢复任务栏请运行 -Show）' -ForegroundColor Green
    exit 0
}

# ---------- 守护循环模式 ----------
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  任务栏守护 v6 运行中（绝对隐藏，按 Win 键唤出）' -ForegroundColor Cyan
Write-Host '  关闭本窗口或运行 -Kill 即可停止' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

Ensure-NormalTaskbarMode
Hide-Taskbar

# ---------- 状态机 ----------
#   'hidden'  = 绝对隐藏（默认）
#   'shown'   = 已唤出（Win 键按下），任务栏保持显示
#   'waiting' = 开始菜单已关闭，延迟后回到 hidden
$state = 'hidden'
$wasWinDown = $false
$menuSeen = $false
$hideAt = Get-Date -Year 2000 -Month 1 -Day 1
$hideDelayMs = 1500

# 记录脚本自身 PID
Write-Host ("[守护 PID: {0}]" -f $PID) -ForegroundColor DarkGray

while ($true) {
    $lwin = [TrayGuardV6]::GetAsyncKeyState($VK_LWIN) -band 0x8000
    $rwin = [TrayGuardV6]::GetAsyncKeyState($VK_RWIN) -band 0x8000
    $winDown = ($lwin -ne 0) -or ($rwin -ne 0)

    # Win 键【按下事件】（边沿触发）
    if ($winDown -and -not $wasWinDown) {
        if ($state -eq 'hidden') {
            Show-Taskbar
            $state = 'shown'
            $script:menuSeen = $false
        } elseif ($state -eq 'waiting') {
            $state = 'shown'
            $script:menuSeen = $false
        }
    }
    $wasWinDown = $winDown

    switch ($state) {
        'hidden' {
            # 绝对隐藏：只要可见就立即藏回
            Hide-Taskbar
        }
        'shown' {
            if (Test-StartMenuVisible) { $script:menuSeen = $true }
        }
        'waiting' {
            if ((Get-Date) -ge $script:hideAt) {
                Hide-Taskbar
                $state = 'hidden'
                $script:menuSeen = $false
            }
        }
    }

    # shown -> waiting：开始菜单出现过，现在关闭了
    if ($state -eq 'shown' -and $script:menuSeen -and -not (Test-StartMenuVisible)) {
        $state = 'waiting'
        $script:hideAt = (Get-Date).AddMilliseconds($hideDelayMs)
    }

    Start-Sleep -Milliseconds 100
}
