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
| **Windows 任务栏** | ✅ 自动隐藏（鼠标移到底部滑出） | ✅ 常驻显示 |
| **壁纸** | 🔒 不变 | 🔒 不变 |

**核心特点：**

- 🖼️ **壁纸完全独立** —— 切换风格不会碰壁纸，换壁纸仍在 `右键桌面 → 个性化 → 背景` 里操作
- 🔄 **零副作用、即时切换** —— 随时开、随时关，不改变任何 Windows 功能与操作习惯
- 🪶 **简单至极** —— 双击一个 `.bat` 即可，无需额外安装、无需配置
- 🛠️ **纯脚本实现** —— 全部基于 PowerShell + 注册表 + 系统消息，无二进制、无后台驻留服务

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
| **任务栏自动隐藏** | 修改注册表 `HKCU\...\Explorer\StuckRects3` 第 `9` 字节（`03`=自动隐藏 / `02`=常驻），重启 `explorer` 生效 |
| **explorer 重启** | 重启后 `HideIcons` 会被重置，脚本自动重新同步图标状态 |

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
