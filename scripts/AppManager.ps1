# =============================================
#  AppManager.ps1 — Windows 应用管理器（macOS Launchpad 风格）
#  =============================================
#  功能：
#    以 macOS Launchpad 风格的网格界面，展示 Windows 上
#    的所有应用（桌面快捷方式 + 开始菜单快捷方式），
#    单击即可启动应用。
#
#  数据来源：
#    - 用户桌面  %USERPROFILE%\Desktop\*.lnk
#    - 公共桌面  C:\Users\Public\Desktop\*.lnk
#    - 开始菜单  用户 + 公共 Start Menu\Programs\*.lnk
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File AppManager.ps1
#
#  依赖：
#    仅需 .NET Framework（Windows 自带 WPF），无第三方库
# =============================================

$ErrorActionPreference = 'SilentlyContinue'

# ---------- 收集所有应用快捷方式 ----------
function Get-AppShortcuts {
    $dirs = @(
        [Environment]::GetFolderPath('Desktop'),
        'C:\Users\Public\Desktop',
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
        'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
    )
    $apps = @()
    foreach ($d in $dirs) {
        if (Test-Path $d) {
            Get-ChildItem $d -Filter '*.lnk' -Recurse -Depth 1 -ErrorAction SilentlyContinue | ForEach-Object {
                $apps += $_
            }
        }
    }
    return $apps
}

# ---------- 解析快捷方式目标 ----------
function Resolve-LnkTarget([string]$lnkPath) {
    try {
        $shell = New-Object -ComObject WScript.Shell
        $sc = $shell.CreateShortcut($lnkPath)
        return @{
            Target = $sc.TargetPath
            Args   = $sc.Arguments
            Icon   = $sc.IconLocation
        }
    } catch {
        return $null
    }
}

# ---------- 提取图标（.lnk 的图标或目标 exe 的图标）----------
function Get-AppIcon([string]$lnkPath) {
    $info = Resolve-LnkTarget $lnkPath
    $iconPath = ''
    if ($info -and $info.Icon -and $info.Icon -match '^(.*?),') { $iconPath = $Matches[1] }
    if (-not $iconPath -or -not (Test-Path $iconPath)) {
        if ($info -and $info.Target) { $iconPath = $info.Target }
    }
    if (-not $iconPath -or -not (Test-Path $iconPath)) { return $null }

    try {
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)
        if ($icon) {
            $bmp = $icon.ToBitmap()
            $hBitmap = $bmp.GetHbitmap()
            $src = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHBitmap(
                $hBitmap, [IntPtr]::Zero,
                [System.Windows.Int32Rect]::Empty,
                [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
            $src.Freeze()
            # 释放资源
            [System.Runtime.InteropServices.Marshal]::Release($hBitmap) | Out-Null
            $bmp.Dispose()
            $icon.Dispose()
            return $src
        }
    } catch { }
    return $null
}

# ---------- 构建 WPF 界面 ----------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName WindowsBase

$apps = Get-AppShortcuts | Sort-Object Name -Unique

# 动态生成 XAML：网格按钮
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
[void]$sb.AppendLine('<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"')
[void]$sb.AppendLine('        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"')
[void]$sb.AppendLine('        Title="应用管理器" Width="900" Height="600"')
[void]$sb.AppendLine('        WindowStartupLocation="CenterScreen"')
[void]$sb.AppendLine('        Background="#1E1E2E" Foreground="White">')
[void]$sb.AppendLine('  <Grid>')
[void]$sb.AppendLine('    <Grid.RowDefinitions>')
[void]$sb.AppendLine('      <RowDefinition Height="Auto"/>')
[void]$sb.AppendLine('      <RowDefinition Height="*"/>')
[void]$sb.AppendLine('      <RowDefinition Height="Auto"/>')
[void]$sb.AppendLine('    </Grid.RowDefinitions>')
[void]$sb.AppendLine('    <TextBlock Grid.Row="0" Text="所有应用" FontSize="24" FontWeight="Bold"')
[void]$sb.AppendLine('               Margin="20,15" Foreground="White"/>')
[void]$sb.AppendLine('    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">')
[void]$sb.AppendLine('      <UniformGrid Columns="6" Margin="20,0,20,20" x:Name="AppGrid"/>')
[void]$sb.AppendLine('    </ScrollViewer>')
[void]$sb.AppendLine('    <TextBlock Grid.Row="2" Text="单击图标启动应用 · 双击标题复制名称"')
[void]$sb.AppendLine('               Margin="20,8" FontSize="12" Foreground="#999"/>')
[void]$sb.AppendLine('  </Grid>')
[void]$sb.AppendLine('</Window>')

$window = [Windows.Markup.XamlReader]::Parse($sb.ToString())
$grid = $window.FindName('AppGrid')

$counter = 0
foreach ($app in $apps) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($app.Name)
    $target = (Resolve-LnkTarget $app.FullName).Target
    if (-not $target) { $target = $app.FullName }

    # 按钮容器
    $btn = New-Object System.Windows.Controls.Button
    $btn.Width = 110
    $btn.Height = 110
    $btn.Margin = New-Object System.Windows.Thickness(6)
    $btn.Background = [System.Windows.Media.Brushes]::Transparent
    $btn.BorderThickness = New-Object System.Windows.Thickness(0)
    $btn.Cursor = [System.Windows.Input.Cursors]::Hand

    # 垂直布局：图标 + 名称
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Orientation = [System.Windows.Controls.Orientation]::Vertical
    $stack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $stack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    # 图标
    $img = New-Object System.Windows.Controls.Image
    $img.Width = 48
    $img.Height = 48
    $img.Margin = New-Object System.Windows.Thickness(0,0,0,8)
    $iconSrc = Get-AppIcon $app.FullName
    if ($iconSrc) {
        $img.Source = $iconSrc
    } else {
        # 无图标时用文字占位
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $name.Substring(0, [math]::Min(2, $name.Length))
        $tb.FontSize = 18
        $tb.Foreground = [System.Windows.Media.Brushes]::White
        $tb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $img = $tb
    }

    # 名称
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $name
    $label.FontSize = 11
    $label.Foreground = [System.Windows.Media.Brushes]::White
    $label.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $label.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $label.MaxWidth = 100
    $label.MaxHeight = 28
    $label.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

    [void]$stack.Children.Add($img)
    [void]$stack.Children.Add($label)
    $btn.Content = $stack

    # 点击打开应用
    $lnkPath = $app.FullName
    $btn.Add_Click({
        param($s, $e)
        Start-Process $lnkPath
    })

    [void]$grid.Children.Add($btn)
    $counter++
}

$window.Title = "应用管理器（$counter 个应用）"
$null = $window.ShowDialog()
