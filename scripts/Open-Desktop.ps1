# =============================================
#  Open-Desktop.ps1 — 打开 Windows 桌面文件夹
#  =============================================
#  功能：
#    打开 Windows 原生桌面文件夹（Explorer 窗口），
#    里面是桌面上的所有软件快捷方式（QQ / 微信 /
#    网易云音乐 / Steam 等）。
#
#    适用于 Mac 风格模式下桌面图标被隐藏的场景：
#    Mac 模式下桌面干净无图标，想快速访问桌面上的
#    软件时，运行本脚本即可打开桌面文件夹。
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File Open-Desktop.ps1
#
#  可选参数：
#    -DesktopPath "C:\Users\xx\Desktop"  指定桌面路径
#                                         （默认当前用户桌面）
# =============================================
param(
    [string]$DesktopPath = ''
)

$ErrorActionPreference = 'SilentlyContinue'

if (-not $DesktopPath) {
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
}

if (Test-Path $DesktopPath) {
    Start-Process explorer.exe -ArgumentList "`"$DesktopPath`""
    Write-Host "[ok] 已打开桌面文件夹: $DesktopPath" -ForegroundColor Green
} else {
    # 备用：用 shell:Desktop 打开
    Write-Host "[warn] 路径不存在: $DesktopPath，改用 shell:Desktop" -ForegroundColor Yellow
    Start-Process explorer.exe -ArgumentList "shell:Desktop"
    Write-Host "[ok] 已打开桌面文件夹 (shell:Desktop)" -ForegroundColor Green
}
