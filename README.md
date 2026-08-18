# 🍎 WinMacStyle

> **Windows 桌面一键切换 macOS 风格** —— 外观苹果化，操作与功能完全保留 Windows 习惯。
>
> 双击开启，Windows 桌面秒变苹果风；再双击，完整还原。

[![Windows](https://img.shields.io/badge/platform-Windows%2010%2F11-0078d6.svg)](https://github.com)
[![PowerShell](https://img.shields.io/badge/script-PowerShell-5391FE.svg)](#)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](/LICENSE)[![许可证：MIT](https://img.shields.io/badge/license-MIT-blue.svg)](/LICENSE)

---

## 📸 效果展示

![macOS 风格效果展示](docs/screenshot.png)(屏幕截图(8).png)



---

## ✨ 功能一览

| 切换项 | 🍎 Mac 风格（开启） | 🪟 Windows 原生（关闭） |
|--------|:---:|:---:|
| **Dock 栏** | ✅ 底部 macOS 风格 Dock | ❌ 关闭 |
| **桌面图标** | ✅ 隐藏（干净桌面） | ✅ 恢复显示 |
| **Windows 任务栏** | ✅ 完全隐藏（按 Win 键唤出，几秒后自动收回） | ✅ 常驻显示 |
| **壁纸** | 🔒 不变 | 🔒 不变 |

**核心特点：**

- 🖼️ **壁纸完全独立** —— 切换风格不会碰壁纸，换壁纸仍在 `右键桌面 → 个性化 → 背景` 里操作
- 🔄 **零副作用、即时切换** —— 随时开、随时关，不改变任何 Windows 功能与操作习惯
- 🪶 **简单至极** —— 双击一个 `.bat` 即可
- 🛠️ **纯脚本实现** —— PowerShell + Win32 API + 注册表，无二进制、无常驻服务
- 🚀 **性能友好** —— 自动关闭 MyDockFinder 的高开销特效，老电脑也不卡

---

## 📥 别人怎么用（新手完整指南）

### 第 1 步：下载本项目

- 点击页面右上角绿色 **`Code`** 按钮 → **`Download ZIP`**
- 解压到任意位置，比如 `D:\WinMacStyle`

### 第 2 步：安装依赖 MyDockFinder（免费）

本工具的 Dock 栏由 **MyDockFinder** 提供，需先安装：

- 免费版下载：<https://github.com/JIAJIA-nya/MyDockFinder-Free>
- 解压后运行 `dock_64.exe` 即可（无需安装，绿色软件）
- **建议解压到 `D:\MyDockFinder`**（脚本会自动检测该路径；装别处需用 `-DockDir` 指定）

> ⚠️ MyDockFinder 是第三方软件，仅作为运行时依赖，请遵守其自身许可。

### 第 3 步：开启 Mac 风格

**方式一：双击运行（推荐）**

1. 双击 **`Enable-MacStyle.bat`** → 桌面变身 macOS 风格（Dock + 隐藏图标 + 任务栏隐藏）
2. 想恢复时双击 **`Disable-MacStyle.bat`** → 回到 Windows 原生

**方式二：命令行**

```powershell
# 开启 Mac 风格
powershell -ExecutionPolicy Bypass -File scripts\WinMacStyle.ps1 -On

# 关闭 Mac 风格
powershell -ExecutionPolicy Bypass -File scripts\WinMacStyle.ps1 -Off

# MyDockFinder 装在别处时指定目录
powershell -ExecutionPolicy Bypass -File scripts\WinMacStyle.ps1 -On -DockDir "D:\Tools\MyDockFinder"
```

### 第 4 步：日常使用技巧

| 想做什么 | 怎么做 |
|---------|--------|
| 临时用任务栏/开始菜单 | 按 **Win 键**，松开几秒后自动隐藏 |
| 打开桌面上的软件 | 运行 `scripts\Open-Desktop.ps1` 打开桌面文件夹 |
| 把常用软件固定到 Dock | **把桌面快捷方式拖到 Dock 上**（MyDockFinder 原生支持） |
| 一键打开所有应用 | 双击桌面 `应用管理器.lnk`（或运行 `scripts\AppManager.ps1`） |
| 换壁纸 | `右键桌面 → 个性化 → 背景`，与切换互不影响 |
| 老电脑卡顿 | 运行 `scripts\Apply-PerfTuning.ps1` 关闭高开销特效 |

---

## 📂 其他脚本说明

| 脚本 | 功能 | 用法 |
|------|------|------|
| `scripts\WinMacStyle.ps1` | 主切换脚本 | `-On` 开启 / `-Off` 关闭 |
| `scripts\TaskbarGuard.ps1` | 任务栏守护（隐藏+Win键唤出） | 由主脚本自动调用 |
| `scripts\AppManager.ps1` | 应用管理器（Launchpad 风格） | 直接运行，点击图标打开应用 |
| `scripts\Open-Desktop.ps1` | 打开桌面文件夹 | 直接运行 |
| `scripts\Apply-PerfTuning.ps1` | 特效调节（折中/Max/Restore） | 直接运行，`-Max` 极致流畅，`-Restore` 全开 |

---

## 🔧 实现原理（纯 Windows 原生方案）

| 功能 | 实现方式 |
|------|---------|
| **桌面图标显隐** | 向桌面视图窗口 `SHELLDLL_DefView` 发送 `WM_COMMAND 0x7402`（等价于右键桌面 → 查看 → 显示桌面图标） |
| **任务栏完全隐藏** | `ShowWindow(Shell_TrayWnd, SW_HIDE)` 隐藏任务栏窗口，后台守护脚本轮询 Win 键，按下时 `SW_SHOW` 唤出、数秒后自动收回 |
| **应用管理器** | PowerShell WPF 网格界面，枚举桌面 + 开始菜单的全部快捷方式，点击启动 |
| **无 explorer 重启** | 图标显隐用消息方式，任务栏用窗口方式，全程不重启 explorer（避免壁纸缓存丢失） |

---

## ⚠️ 注意事项

- 首次运行若被安全软件拦截，请添加信任或以管理员身份运行
- 脚本仅修改 `HideIcons` 注册表键与任务栏窗口显示状态，不改变系统其他设置
- 切换时任务栏会闪烁一下（隐藏窗口所致），属正常现象
- 建议安装到 **D 盘**（软件盘），C 盘留给系统

---

## 📄 许可证

[MIT License](/LICENSE) ✨ 自由使用、修改、分发，保留版权声明即可。

---

## 🙏 致谢

- [MyDockFinder](https://www.mydockfinder.com/) — 提供 macOS 风格 Dock
- [LAYTAT/macOS-Wallpapers](https://github.com/LAYTAT/macOS-Wallpapers) — macOS 官方壁纸合集
