<<<<<<< HEAD
# 🍎 WinMacStyle

> **Windows 桌面一键切换 macOS 风格** —— 外观苹果化，操作与功能完全保留 Windows 习惯。
>
> 双击开启，Windows 桌面秒变苹果风；再双击，完整还原。

[![Windows](https://img.shields.io/badge/platform-Windows%2010%2F11-0078d6.svg)](https://github.com)
[![PowerShell](https://img.shields.io/badge/script-PowerShell-5391FE.svg)](#)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](/LICENSE)

---

## 📸 效果展示

> 图片放法：把你的桌面截图保存为 `docs/screenshot.png`，GitHub 会自动显示。
> 截图技巧：开启 Mac 风格后按 `Win + Shift + S` 或 `Win + PrtScn` 截屏。

![macOS 风格效果展示](docs/screenshot.png)

*↑ 示意图位置：在 Mac 风格开启状态下截一张桌面图，替换 `docs/screenshot.png` 即可*

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
- 🪶 **简单至极** —— 双击一个 `.bat` 即可，无需额外安装、无需配置
- 🛠️ **纯脚本实现** —— 全部基于 PowerShell + Win32 API + 注册表，无二进制、无常驻服务
- 🚀 **性能友好** —— 自动关闭 MyDockFinder 的高开销特效（毛玻璃/动画/缩略图），老电脑也不卡

---

## 📦 依赖

本工具只是一个切换脚本，真正的 Dock 栏由 **MyDockFinder**（免费）提供：

- 免费版下载：<https://github.com/JIAJIA-nya/MyDockFinder-Free>
- 官方网站：<https://www.mydockfinder.com/>
- 默认装在 `D:\MyDockFinder`，脚本会自动检测常见安装路径；装在别处时用 `-DockDir` 指定即可

> ⚠️ MyDockFinder 为第三方软件，仅作为本工具的运行时依赖，请遵守其自身许可。

---

## 🚀 快速开始

### 方式一：双击运行（推荐）

1. 下载并解压本项目
2. 双击 **`Enable-MacStyle.bat`** → 桌面变身 macOS 风格
3. 双击 **`Disable-MacStyle.bat`** → 恢复 Windows 原生

### 方式二：命令行

```powershell
# 开启 Mac 风格
powershell -ExecutionPolicy Bypass -File scripts\WinMacStyle.ps1 -On

# 关闭 Mac 风格
powershell -ExecutionPolicy Bypass -File scripts\WinMacStyle.ps1 -Off

# 指定 MyDockFinder 安装目录（装在其他路径时）
powershell -ExecutionPolicy Bypass -File scripts\WinMacStyle.ps1 -On -DockDir "D:\Tools\MyDockFinder"
```

---

## 📂 访问桌面软件（Mac 模式下）

Mac 模式下桌面图标被隐藏，想打开 Windows 桌面上的软件（QQ / 微信 / 网易云等）时：

**方式一：打开桌面文件夹（脚本，推荐）**

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Open-Desktop.ps1
```

会打开一个资源管理器窗口显示桌面内容，所有桌面快捷方式都在里面。

**方式二：拖拽添加到 Dock（MyDockFinder 原生）**

直接把桌面上的快捷方式**拖到 Dock 栏**上即可固定，以后在 Mac 模式下直接点 Dock 图标打开：

![拖拽添加](docs/screenshot.png)

> 💡 MyDockFinder 的 Dock 图标由程序内部管理（启动时恢复），不推荐直接改配置文件 `ico.ini`。

---

## 🖼️ 壁纸

macOS 官方壁纸（Sonoma / Ventura / Sequoia / Tahoe 等）整理在 `wallpaper/macos/` 目录：

- **使用**：`右键桌面 → 个性化 → 背景 → 浏览`，选择目录里的图片
- **独立**：壁纸与风格切换互不影响，可任意组合
- 壁纸来源：[LAYTAT/macOS-Wallpapers](https://github.com/LAYTAT/macOS-Wallpapers)（版权归 Apple Inc.，故不随仓库分发，请自行下载放入）

---

## 🔧 实现原理（纯 Windows 原生方案）

| 功能 | 实现方式 |
|------|---------|
| **桌面图标显隐** | 向桌面视图窗口 `SHELLDLL_DefView` 发送 `WM_COMMAND 0x7402`（等价于右键桌面 → 查看 → 显示桌面图标） |
| **任务栏完全隐藏** | `ShowWindow(Shell_TrayWnd, SW_HIDE)` 隐藏任务栏窗口，后台守护脚本轮询 Win 键，按下时 `SW_SHOW` 唤出、数秒后自动收回（`scripts/TaskbarGuard.ps1`） |
| **性能优化** | 自动写入 MyDockFinder 配置：关闭毛玻璃模糊（`blurvalue=0`）、图标特效（`dockicoeffect=0`）、窗口动画（`AnimationEffect=0`）、缩略图（`DWMThumbnail/enabled=0`） |
| **无 explorer 重启** | 图标显隐用消息方式，任务栏用窗口方式，全程不重启 explorer（避免壁纸缓存丢失） |

---

## ⚠️ 注意事项

- 切换时任务栏会**闪烁一下**（需重启 explorer 使任务栏设置生效），属正常现象
- Mac 模式下想临时用任务栏，把鼠标移到**屏幕最底部**即可滑出
- 若 MyDockFinder 被安全软件拦截，请在防火墙/杀软中添加信任，或以管理员身份运行
- 脚本仅修改 `HideIcons` 与 `StuckRects3` 两个注册表键，建议按需提前备份

---

## 📄 许可证

[MIT License](/LICENSE) ✨ 自由使用、修改、分发，保留版权声明即可。

---

## 🙏 致谢

- [MyDockFinder](https://www.mydockfinder.com/) — 提供 macOS 风格 Dock
- [LAYTAT/macOS-Wallpapers](https://github.com/LAYTAT/macOS-Wallpapers) — macOS 官方壁纸合集
=======
# WinMacStyle
一键把 Windows 桌面切换成 macOS 风格（Dock + 隐藏图标 + 任务栏自动隐藏），外观苹果化、操作保留 Windows 习惯；双击即可在两种风格间自由切换，壁纸完全独立。
>>>>>>> 328b39aae6c47271ab2daa6c98f1c0a849f9340c
