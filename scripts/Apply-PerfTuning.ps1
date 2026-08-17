# =============================================
#  Apply-PerfTuning.ps1 — MyDockFinder 特效调节
#  =============================================
#  功能：
#    在"macOS 视觉效果"与"流畅度"之间调节 MyDockFinder。
#
#  三种模式：
#    (默认) 折中模式：保留图标特效/动画/模糊(15)，
#                     关闭最耗资源的窗口缩略图与 Aero Peek
#    -Max         极致流畅：关闭模糊/特效/动画/缩略图
#    -Restore     完全恢复：全部特效打开（出厂感觉）
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File Apply-PerfTuning.ps1
#    powershell -ExecutionPolicy Bypass -File Apply-PerfTuning.ps1 -Max
#    powershell -ExecutionPolicy Bypass -File Apply-PerfTuning.ps1 -Restore
#
#  可选参数：
#    -DockDir "D:\MyDockFinder"   指定 MyDockFinder 目录（默认自动检测）
# =============================================
param(
    [string]$DockDir = '',
    [switch]$Max,
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

# 各模式下每个配置项的目标值
$values = @{
    'dockicoeffect' = 1; 'blurvalue' = 30; 'maxsize' = 128;
    'thumb_enabled' = 1; 'aeropeek' = 1;
    'min_enabled' = 1; 'anim_effect' = 1; 'anim_enable' = 1
}
if ($Max) {
    $values['dockicoeffect'] = 0; $values['blurvalue'] = 0; $values['maxsize'] = 96
    $values['thumb_enabled'] = 0; $values['aeropeek'] = 0
    $values['min_enabled'] = 0; $values['anim_effect'] = 0; $values['anim_enable'] = 0
} elseif (-not $Restore) {
    # 折中模式（默认）
    $values['blurvalue'] = 15; $values['maxsize'] = 112
    $values['thumb_enabled'] = 0; $values['aeropeek'] = 0
    # 其余保持全开（图标特效/动画）
}

$lines = [System.IO.File]::ReadAllLines($cfg, [System.Text.Encoding]::UTF8)
$out = New-Object System.Collections.ArrayList
$section = ''
foreach ($l in $lines) {
    if ($l -match '^\[(.+)\]$') { $section = $Matches[1] }
    $new = $l
    switch ($section) {
        'normal' {
            if ($l -match '^dockicoeffect=') { $new = "dockicoeffect=$($values['dockicoeffect'])" }
            if ($l -match '^blurvalue=')     { $new = "blurvalue=$($values['blurvalue'])" }
            if ($l -match '^maxsize=')       { $new = "maxsize=$($values['maxsize'])" }
        }
        'DWMThumbnail' {
            if ($l -match '^enabled=')  { $new = "enabled=$($values['thumb_enabled'])" }
            if ($l -match '^aeropeek=') { $new = "aeropeek=$($values['aeropeek'])" }
        }
        'minimize' {
            if ($l -match '^enabled=') { $new = "enabled=$($values['min_enabled'])" }
        }
        'WindowsOpen' {
            if ($l -match '^AnimationEffect=') { $new = "AnimationEffect=$($values['anim_effect'])" }
            if ($l -match '^enable=')          { $new = "enable=$($values['anim_enable'])" }
        }
    }
    [void]$out.Add($new)
}
[System.IO.File]::WriteAllLines($cfg, $out.ToArray(), [System.Text.Encoding]::UTF8)

$modeName = if ($Max) { '极致流畅（全关特效）' } elseif ($Restore) { '完全恢复（全开特效）' } else { '折中（保留感觉+省资源）' }
Write-Host "[ok] 已应用模式: $modeName" -ForegroundColor Green

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
