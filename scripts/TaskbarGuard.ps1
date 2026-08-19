# =============================================
#  TaskbarGuard.ps1 — 任务栏守护 v5（绝对隐藏 + Win 键唤出）
#  =============================================
#  行为（macOS 模式，严格符合需求）：
#    - 平时：任务栏【绝对隐藏】——鼠标移到屏幕底部、
#      软件退出、窗口切换、explorer 刷新，任何情况都不会出现
#    - 按【一下】Win 键：任务栏出现（开始菜单弹出）
#    - 唤出后：任务栏保持可用，鼠标移到最底部等操作正常
#      （不会按一下就立即消失）
#    - 开始菜单关闭后：任务栏自动重新隐藏
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1        # 前台运行（守护）
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Hide  # 仅隐藏后退出
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Show  # 仅显示后退出
#    powershell -ExecutionPolicy Bypass -File TaskbarGuard.ps1 -Kill  # 结束后台守护
#
#  原理：
#    - 高频轮询（100ms）强制隐藏任务栏，除非处于"唤出状态"
#    - 检测 Win 键【按下事件】（边沿触发：从松开变为按下）
#      -> 进入唤出状态，任务栏显示并保持
#    - 唤出状态下监听开始菜单：菜单出现后关闭 -> 延迟隐藏
#    - 若按 Win 后开始菜单始终未出现（如被其他用途），
#      8 秒超时后仍保持显示（用户可能正在使用任务栏），
#      直到再次检测到开始菜单开合周期才隐藏
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
public class TrayGuardV5 {
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
        $h = [TrayGuardV5]::FindWindow($cls, $null)
        if ($h -ne [IntPtr]::Zero) { $hs += $h }
    }
    return $hs
}

function Hide-Taskbar {
    foreach ($h in (Get-TrayHandles)) {
        if ([TrayGuardV5]::IsWindowVisible($h)) { [TrayGuardV5]::ShowWindow($h, 0) | Out-Null }
    }
}

function Show-Taskbar {
    foreach ($h in (Get-TrayHandles)) {
        if (-not [TrayGuardV5]::IsWindowVisible($h)) { [TrayGuardV5]::ShowWindow($h, 5) | Out-Null }
    }
}

function Test-StartMenuVisible {
    # 开始菜单由 StartMenuExperienceHost 进程承载，检查其主窗口可见性
    $sm = Get-Process -Name 'StartMenuExperienceHost' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sm -and $sm.MainWindowHandle -ne 0) {
        return [TrayGuardV5]::IsWindowVisible($sm.MainWindowHandle)
    }
    return $false
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
Write-Host '  任务栏守护运行中（绝对隐藏，按 Win 键唤出）' -ForegroundColor Cyan
Write-Host '  关闭本窗口或运行 -Kill 即可停止' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

# 确保 Windows 任务栏处于"常驻"模式（StuckRects3=02），
# 关闭系统自带的"自动隐藏"逻辑（否则鼠标移到底部会滑出任务栏）
try {
    $regStuck = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    $sr = (Get-ItemProperty $regStuck -Name Settings -ErrorAction SilentlyContinue).Settings
    if ($sr -and $sr.Length -gt 8 -and $sr[8] -ne 2) {
        $sr[8] = 2
        Set-ItemProperty $regStuck -Name Settings -Value $sr -Type Binary
    }
} catch { }

# 初始状态：隐藏
Hide-Taskbar

# ---------- 状态机 ----------
#   'hidden'  = 绝对隐藏（默认）——任务栏强制不可见
#   'shown'   = 已唤出（按过 Win 键）——任务栏保持显示、可操作
#   'waiting' = 开始菜单已关闭——延迟后回到 hidden
$state = 'hidden'
$wasWinDown = $false
$menuSeen = $false          # 本次唤出周期内是否见过开始菜单
$hideAt = Get-Date -Year 2000 -Month 1 -Day 1
$hideDelayMs = 2000         # 菜单关闭后延迟隐藏时间（给用户操作缓冲）

while ($true) {
    $lwin = [TrayGuardV5]::GetAsyncKeyState($VK_LWIN) -band 0x8000
    $rwin = [TrayGuardV5]::GetAsyncKeyState($VK_RWIN) -band 0x8000
    $winDown = ($lwin -ne 0) -or ($rwin -ne 0)

    # 检测 Win 键【按下事件】（边沿触发：从松开变为按下）
    if ($winDown -and -not $wasWinDown) {
        if ($state -eq 'hidden') {
            Show-Taskbar
            $state = 'shown'
            $script:menuSeen = $false
            Write-Host ("[{0}] Win 键按下 -> 任务栏唤出" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
        } elseif ($state -eq 'waiting') {
            # 等待隐藏期间又按了 Win：回到 shown
            $state = 'shown'
            $script:menuSeen = $false
            Write-Host ("[{0}] 再次按 Win -> 保持显示" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
        }
    }
    $wasWinDown = $winDown

    switch ($state) {
        'hidden' {
            # 绝对隐藏：只要可见就立即藏回
            Hide-Taskbar
        }
        'shown' {
            # 唤出状态：任务栏保持显示，不主动隐藏
            # 记录开始菜单是否出现过
            if (Test-StartMenuVisible) { $script:menuSeen = $true }
        }
        'waiting' {
            # 等待隐藏：任务栏仍保持显示（用户可能还在操作）
            if ((Get-Date) -ge $script:hideAt) {
                Hide-Taskbar
                $state = 'hidden'
                $script:menuSeen = $false
                Write-Host ("[{0}] 任务栏已重新隐藏" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
            }
        }
    }

    # shown -> waiting 转换：开始菜单出现过，现在关闭了
    if ($state -eq 'shown' -and $script:menuSeen -and -not (Test-StartMenuVisible)) {
        $state = 'waiting'
        $script:hideAt = (Get-Date).AddMilliseconds($hideDelayMs)
        Write-Host ("[{0}] 开始菜单关闭 -> 准备隐藏" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
    }

    Start-Sleep -Milliseconds 100
}
