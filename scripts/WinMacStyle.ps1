# =============================================
#  WinMacStyle.ps1 — Windows ↔ macOS 风格一键切换
#  =============================================
#  功能：
#    - 启动/关闭 MyDockFinder Dock 栏（macOS 风格）
#    - 显示/隐藏桌面图标（macOS 干净桌面）
#    - 自动隐藏/常驻 Windows 任务栏
#    - 壁纸完全不受影响（由 Windows 设置统一管理）
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File WinMacStyle.ps1 -On
#    powershell -ExecutionPolicy Bypass -File WinMacStyle.ps1 -Off
#
#  可选参数：
#    -DockDir "D:\MyDockFinder"   指定 MyDockFinder 安装目录
#                                  （默认自动检测常见位置）
#
#  原理：
#    - 桌面图标：向 SHELLDLL_DefView 发送 WM_COMMAND 0x7402
#      （等价于右键桌面 -> 查看 -> 显示桌面图标 菜单）
#    - 任务栏自动隐藏：修改 StuckRects3 注册表第 9 字节
#      （03=自动隐藏 02=常驻），然后重启 explorer 生效
#    - 注意：重启 explorer 会把 HideIcons 重置，脚本在重启后
#      重新同步图标状态
# =============================================
param(
    [switch]$On,
    [switch]$Off,
    [string]$DockDir = ''
)

$ErrorActionPreference = 'SilentlyContinue'
$regAdvanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$regStuck = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'

# ---------- 自动检测 MyDockFinder 安装目录 ----------
function Find-DockDir {
    $candidates = @(
        $DockDir,
        'D:\MyDockFinder',
        'C:\MyDockFinder',
        'D:\MyDockFinder-Free',
        'C:\MyDockFinder-Free',
        "$env:LOCALAPPDATA\MyDockFinder",
        "$env:ProgramFiles\MyDockFinder"
    ) | Where-Object { $_ -ne '' }
    foreach ($dir in $candidates) {
        if (Test-Path (Join-Path $dir 'dock_64.exe')) { return $dir }
        if (Test-Path (Join-Path $dir 'dock.exe')) { return $dir }
    }
    # 最后尝试：从运行中的进程推断
    $proc = Get-Process -Name 'Dock_64','dock' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
        $p = $proc.Path
        if ($p) { return Split-Path $p -Parent }
    }
    return ''
}

# ---------- 窗口 API ----------
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class DeskWin {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hParent, EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
'@

function Find-DesktopView {
    # 返回 SHELLDLL_DefView 窗口句柄（桌面图标宿主）
    $script:foundProgman = [IntPtr]::Zero
    $script:foundDefView = [IntPtr]::Zero
    $cb0 = [DeskWin+EnumWindowsProc]{
        param($h, $l)
        $c = New-Object System.Text.StringBuilder 256
        [DeskWin]::GetClassName($h, $c, 256) | Out-Null
        if ($c.ToString() -eq 'Progman') { $script:foundProgman = $h }
        return $true
    }
    [DeskWin]::EnumWindows($cb0, [IntPtr]::Zero) | Out-Null
    if ($script:foundProgman -eq [IntPtr]::Zero) { return [IntPtr]::Zero }
    $cb = [DeskWin+EnumWindowsProc]{
        param($h, $l)
        $c = New-Object System.Text.StringBuilder 256
        [DeskWin]::GetClassName($h, $c, 256) | Out-Null
        if ($c.ToString() -eq 'SHELLDLL_DefView') { $script:foundDefView = $h }
        return $true
    }
    [DeskWin]::EnumChildWindows($script:foundProgman, $cb, [IntPtr]::Zero) | Out-Null
    return $script:foundDefView
}

function Get-HideIcons {
    $v = (Get-ItemProperty $regAdvanced -Name 'HideIcons' -ErrorAction SilentlyContinue).HideIcons
    if ($null -eq $v) { $v = 0 }
    return [int]$v
}

function Set-DesktopIcons([bool]$show) {
    # 目标: $true=显示(0)  $false=隐藏(1)
    $target = if ($show) { 0 } else { 1 }
    $current = Get-HideIcons
    if ($current -eq $target) {
        Write-Host "  [info] 桌面图标已是目标状态 (HideIcons=$current)"
        return
    }
    $defView = Find-DesktopView
    if ($defView -ne [IntPtr]::Zero) {
        [DeskWin]::SendMessage($defView, 0x0111, [IntPtr]0x7402, [IntPtr]0) | Out-Null
        Start-Sleep -Seconds 1
        Set-ItemProperty $regAdvanced -Name 'HideIcons' -Value $target -Type DWord
        Write-Host "  [ok] 桌面图标已$(if($show){'显示'}else{'隐藏'})"
    } else {
        Set-ItemProperty $regAdvanced -Name 'HideIcons' -Value $target -Type DWord
        Write-Host "  [warn] 未找到桌面视图，已直接设置注册表 HideIcons=$target" -ForegroundColor Yellow
    }
}

function Set-TaskbarAutoHide([bool]$autoHide) {
    # $true=自动隐藏任务栏  $false=常驻显示
    # StuckRects3 Settings 第 9 字节: 03=自动隐藏 02=正常
    $val = if ($autoHide) { 3 } else { 2 }
    $settings = (Get-ItemProperty $regStuck -Name Settings -ErrorAction SilentlyContinue).Settings
    if ($null -eq $settings) {
        Write-Host "  [warn] 未找到 StuckRects3 设置，跳过任务栏设置" -ForegroundColor Yellow
        return
    }
    $settings[8] = $val
    Set-ItemProperty $regStuck -Name Settings -Value $settings -Type Binary
    Write-Host "  [ok] 任务栏已设为$(if($autoHide){'自动隐藏（鼠标移到底部滑出）'}else{'常驻显示'})"
}

function Restart-Explorer {
    # 重启 explorer 让任务栏设置生效；重启后同步桌面图标状态
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
    Start-Sleep -Seconds 4
    Write-Host "  [ok] explorer 已重启 (PID $((Get-Process explorer -ErrorAction SilentlyContinue).Id))"
}

function Test-DockRunning {
    $p = Get-Process -Name 'Dock_64','dock','Dockmod','Dockmod64','Dockmod64arm' -ErrorAction SilentlyContinue
    return ($null -ne $p)
}

function Start-MacStyle {
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '  开启 Mac 风格 ...' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan

    $dockDir = Find-DockDir
    if (-not $dockDir) {
        Write-Host '  [error] 未找到 MyDockFinder，请先安装或用 -DockDir 指定目录' -ForegroundColor Red
        Write-Host '          下载: https://github.com/JIAJIA-nya/MyDockFinder-Free' -ForegroundColor Yellow
        return
    }
    $dockExe = Join-Path $dockDir 'dock_64.exe'
    if (-not (Test-Path $dockExe)) { $dockExe = Join-Path $dockDir 'dock.exe' }
    Write-Host "  使用 Dock: $dockExe" -ForegroundColor DarkGray

    # 1. 启动 Dock
    if (-not (Test-DockRunning)) {
        Start-Process -FilePath $dockExe -WorkingDirectory $dockDir
        Write-Host '  [1/4] MyDockFinder 已启动' -ForegroundColor Green
        Start-Sleep -Seconds 3
    } else {
        Write-Host '  [1/4] MyDockFinder 已在运行' -ForegroundColor Green
    }

    # 2. 隐藏桌面图标
    Write-Host '  [2/4] 隐藏桌面图标 ...' -ForegroundColor Green
    Set-DesktopIcons -show $false

    # 3. 启动任务栏守护（完全隐藏任务栏，按 Win 键唤出）
    Write-Host '  [3/4] 启动任务栏守护（隐藏任务栏，按 Win 键唤出）...' -ForegroundColor Green
    $guardScript = Join-Path $PSScriptRoot 'TaskbarGuard.ps1'
    if (Test-Path $guardScript) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$guardScript`""
        Start-Sleep -Seconds 2
        Write-Host '  [ok] 任务栏守护已启动'
    } else {
        Write-Host '  [warn] 未找到 TaskbarGuard.ps1，仅隐藏任务栏窗口（不启用自动隐藏）' -ForegroundColor Yellow
        # 保持 StuckRects3=02（常驻），只硬隐藏窗口，避免鼠标悬停滑出
    }

    # 4. 隐藏任务栏窗口（无需重启 explorer）
    Write-Host '  [4/4] 隐藏任务栏窗口 ...' -ForegroundColor Green
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TrayH {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@
        $th = [TrayH]::FindWindow('Shell_TrayWnd', $null)
        if ($th -ne [IntPtr]::Zero) { [TrayH]::ShowWindow($th, 0) | Out-Null; Write-Host '  [ok] 任务栏已隐藏' }
    } catch { }

    Write-Host ''
    Write-Host '  Mac 风格已开启！' -ForegroundColor Green
    Write-Host '  - Dock 栏 + 桌面无图标 + 任务栏完全隐藏' -ForegroundColor Green
    Write-Host '  - 壁纸保持不变（Windows 设置 -> 个性化 统一管理）' -ForegroundColor DarkGray
    Write-Host '  提示: 按 Win 键唤出任务栏/开始菜单，松开几秒后自动隐藏' -ForegroundColor Yellow
}

function Stop-MacStyle {
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '  关闭 Mac 风格，恢复 Windows 原生 ...' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan

    # 1. 关闭 Dock
    if (Test-DockRunning) {
        Get-Process -Name 'Dock_64','dock','Dockmod','Dockmod64','Dockmod64arm' -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Host '  [1/4] MyDockFinder 已关闭' -ForegroundColor Green
        Start-Sleep -Seconds 2
    } else {
        Write-Host '  [1/4] MyDockFinder 未在运行' -ForegroundColor Green
    }

    # 2. 停止任务栏守护并恢复任务栏
    Write-Host '  [2/4] 停止任务栏守护，恢复任务栏 ...' -ForegroundColor Green
    $guardScript = Join-Path $PSScriptRoot 'TaskbarGuard.ps1'
    if (Test-Path $guardScript) {
        # 结束已有的守护进程
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -match 'TaskbarGuard' } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        # 显示任务栏窗口
        powershell -NoProfile -ExecutionPolicy Bypass -File $guardScript -Show 2>$null
    } else {
        Set-TaskbarAutoHide -autoHide $false
    }

    # 3. 恢复桌面图标（消息方式，不重启 explorer）
    Write-Host '  [3/4] 恢复桌面图标 ...' -ForegroundColor Green
    Set-DesktopIcons -show $true

    Write-Host ''
    Write-Host '  已恢复 Windows 原生桌面！壁纸保持不变' -ForegroundColor Green
}

if ($On) {
    Start-MacStyle
} elseif ($Off) {
    Stop-MacStyle
} else {
    Write-Host '用法: WinMacStyle.ps1 -On  开启 Mac 风格' -ForegroundColor Yellow
    Write-Host '       WinMacStyle.ps1 -Off 恢复 Windows 原生' -ForegroundColor Yellow
    Write-Host '       -DockDir "路径"  指定 MyDockFinder 目录（可选）' -ForegroundColor Yellow
}
