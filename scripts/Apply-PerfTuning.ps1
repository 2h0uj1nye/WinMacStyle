# =============================================
#  Apply-PerfTuning.ps1 — 一键优化 MyDockFinder 性能
#  =============================================
#  功能：
#    关闭 MyDockFinder 的高开销视觉效果，让低配置电脑
#    也能流畅运行：
#      - 毛玻璃模糊  blurvalue: 30 -> 0
#      - 图标特效    dockicoeffect: 1 -> 0
#      - 窗口缩略图  DWMThumbnail/enabled: 1 -> 0
#      - 最小化动画  minimize/enabled: 1 -> 0
#      - 窗口动画    WindowsOpen/AnimationEffect: 1 -> 0
#      - 图标放大上限 maxsize: 128 -> 96
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File Apply-PerfTuning.ps1
#
#  可选参数：
#    -DockDir "D:\MyDockFinder"   指定 MyDockFinder 目录（默认自动检测）
#    -Restore                      恢复备份的原始配置
# =============================================
param(
    [string]$DockDir = '',
    [switch]$Restore
)

$ErrorActionPreference = 'SilentlyContinue'

# ---------- 自动检测 MyDockFinder 目录 ----------
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
    return ''
}

$dockDir = Find-DockDir
if (-not $dockDir) {
    Write-Host '[error] 未找到 MyDockFinder，请先安装或用 -DockDir 指定目录' -ForegroundColor Red
    exit 1
}
$cfg = Join-Path $dockDir 'config.ini'
if (-not (Test-Path $cfg)) {
    Write-Host "[error] 未找到配置文件: $cfg" -ForegroundColor Red
    exit 1
}

Write-Host "MyDockFinder: $dockDir" -ForegroundColor DarkGray

if ($Restore) {
    # 恢复原始配置
    $bak = "$cfg.orig"
    if (Test-Path $bak) {
        Copy-Item $bak $cfg -Force
        Write-Host '[ok] 已恢复原始配置' -ForegroundColor Green
    } else {
        Write-Host '[warn] 未找到原始备份，跳过' -ForegroundColor Yellow
    }
} else {
    # 首次备份原始配置
    if (-not (Test-Path "$cfg.orig")) {
        Copy-Item $cfg "$cfg.orig" -Force
        Write-Host '已备份原始配置到 config.ini.orig' -ForegroundColor DarkGray
    }

    # 逐段逐行优化
    $lines = [System.IO.File]::ReadAllLines($cfg, [System.Text.Encoding]::UTF8)
    $out = New-Object System.Collections.ArrayList
    $section = ''
    foreach ($l in $lines) {
        if ($l -match '^\[(.+)\]$') { $section = $Matches[1] }
        $new = $l
        switch ($section) {
            'normal' {
                if ($l -match '^dockicoeffect=') { $new = 'dockicoeffect=0' }
                if ($l -match '^blurvalue=')     { $new = 'blurvalue=0' }
                if ($l -match '^maxsize=')       { $new = 'maxsize=96' }
            }
            'DWMThumbnail' {
                if ($l -match '^enabled=')  { $new = 'enabled=0' }
                if ($l -match '^aeropeek=') { $new = 'aeropeek=0' }
            }
            'minimize' {
                if ($l -match '^enabled=') { $new = 'enabled=0' }
            }
            'WindowsOpen' {
                if ($l -match '^AnimationEffect=') { $new = 'AnimationEffect=0' }
                if ($l -match '^enable=')          { $new = 'enable=0' }
            }
        }
        [void]$out.Add($new)
    }
    [System.IO.File]::WriteAllLines($cfg, $out.ToArray(), [System.Text.Encoding]::UTF8)
    Write-Host '[ok] 性能优化已应用（模糊/特效/动画/缩略图已关闭）' -ForegroundColor Green
}

# 重启 Dock 生效
Write-Host '重启 MyDockFinder 使配置生效 ...' -ForegroundColor Cyan
Get-Process -Name 'Dock_64','dock','Dockmod','Dockmod64','Dockmod64arm' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
$dockExe = Join-Path $dockDir 'dock_64.exe'
if (-not (Test-Path $dockExe)) { $dockExe = Join-Path $dockDir 'dock.exe' }
Start-Process -FilePath $dockExe -WorkingDirectory $dockDir
Start-Sleep -Seconds 3
$p = Get-Process -Name 'Dock_64' -ErrorAction SilentlyContinue
if ($p) {
    Write-Host ("[ok] Dock 已重启 (PID {0})" -f $p.Id) -ForegroundColor Green
} else {
    Write-Host '[warn] Dock 启动检查超时，请手动确认' -ForegroundColor Yellow
}
