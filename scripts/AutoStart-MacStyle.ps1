# =============================================
#  AutoStart-MacStyle.ps1 — 开机自动进入 macOS 风格
#  =============================================
#  功能：
#    开机后自动执行 WinMacStyle.ps1 -On，
#    进入完整 macOS 风格（Dock + 隐藏图标 + 任务栏隐藏）。
#
#  设计：
#    - 延迟 15 秒启动（等待系统完全加载、explorer 就绪）
#    - 启动前强制设置 StuckRects3=02（任务栏常驻模式），
#      防止系统"自动隐藏"逻辑导致鼠标悬停滑出任务栏
#    - 通过启动文件夹快捷方式调用
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File AutoStart-MacStyle.ps1
# =============================================

$ErrorActionPreference = 'SilentlyContinue'

# 等待系统就绪（explorer 加载完）
Start-Sleep -Seconds 15

# 确保任务栏常驻模式（StuckRects3=02），杜绝鼠标悬停滑出
try {
    $regStuck = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    $sr = (Get-ItemProperty $regStuck -Name Settings -ErrorAction SilentlyContinue).Settings
    if ($sr -and $sr.Length -gt 8) {
        if ($sr[8] -ne 2) {
            $sr[8] = 2
            Set-ItemProperty $regStuck -Name Settings -Value $sr -Type Binary
            # 通知 explorer 刷新
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TBShc {
    [DllImport("shell32.dll")] public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
'@
            [TBShc]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        }
    }
} catch { }

# 执行 Mac 风格开启（含 Dock 启动、图标隐藏、任务栏守护）
$script = 'C:\Users\Administrator\Documents\WinMacStyle\scripts\WinMacStyle.ps1'
if (Test-Path $script) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -On" -WindowStyle Minimized
}
