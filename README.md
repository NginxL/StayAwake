<p align="center">
  <img src="docs/AppIcon.png" width="120" alt="醒着的咖啡杯图标" />
</p>

<h1 align="center">醒着 · StayAwake</h1>
<p align="center">给 Mac 续一杯。轻巧、原生、中文的菜单栏防休眠工具。</p>

<p align="center">macOS 14+ · Swift / SwiftUI · Apple Silicon & Intel · MIT</p>

## 功能

- **随手开关**：左键点菜单栏咖啡杯打开面板；右键直接开启 / 暂停。
- **按需计时**：无限、15 / 30 / 45 分钟、1 / 4 / 8 小时，或自定义 1–1440 分钟。
- **清楚可见**：面板倒计时、剩余时间进度条，可选菜单栏倒计时。
- **屏幕独立控制**：保持 Mac 运行的同时，自行决定屏幕是否常亮。
- **登录启动**：可选随登录打开；防休眠默认关闭，需要手动开启。

关闭、到期或退出后，释放本应用的防休眠请求。防休眠功能离线工作，没有统计上报或第三方依赖。
只有手动检查 / 下载更新、打开源码链接时才访问 GitHub。

## 安装与更新

从 [Releases](https://github.com/NginxL/StayAwake/releases/latest) 下载 `StayAwake-版本-universal.zip`，
解压后把 `StayAwake.app` 放到 `/Applications` 或 `~/Applications`。应用同时提供菜单栏入口和 Dock 图标，
可在 Dock 图标上右键选择「选项 → 在程序坞中保留」。

在面板的「设置 → 版本更新」中点击 **检查更新**；发现新版本后点击 **下载并安装**。
该操作会结束当前防休眠会话、替换应用并重新打开。重新打开后默认不启用防休眠。

更新只接受此仓库正式 Release 的通用安装包，检查 SHA-256、应用标识、版本号和代码签名完整性。
SHA-256 校验用于检测损坏，**不等同于 Apple Developer ID 签名或公证**。
更新只在你点击时执行；权限不足、网络错误或校验失败时保留已安装版本。
替换目录失败时恢复旧版本，上一版本保留在应用所在目录的 `.StayAwake-previous.app`，可手动恢复。

## 本地构建与使用

要求 macOS 14 或更新版本、Swift 5.9+。安装 Apple Command Line Tools 即可，不需要完整 Xcode：

```bash
xcode-select --install  # 已安装时跳过
git clone https://github.com/NginxL/StayAwake.git
cd StayAwake
bash scripts/build.sh
```

生成的应用在 `dist/StayAwake.app`。在 Finder 中打开即可使用；日常使用可将它拖入「应用程序」。
设置登录启动前，建议先将应用放在固定位置。

```bash
# 运行核心逻辑测试；不依赖 XCTest 或完整 Xcode
bash scripts/test.sh

# 在本机短暂创建防休眠请求，验证超时、屏幕开关和强制退出后的释放
bash scripts/test.sh --integration

# 同时编译 Apple Silicon 和 Intel，合成为通用应用并打包
bash scripts/package.sh --universal
```

构建产物使用本地 ad-hoc 签名，**没有 Apple Developer ID 签名或公证**。
从网上下载的二进制文件可能被 Gatekeeper 拦截；可在自己机器上从源码构建。
脚本不会关闭 Gatekeeper，也不会修改系统安全设置。

## 使用说明

| 操作 | 结果 |
| --- | --- |
| 选择时长，再打开主开关 | 从当前时间开始防休眠 |
| 正在运行时更改时长 | 从当前时间按新时长重新计时 |
| 正在运行时切换屏幕常亮 | 保留原来的结束时间 |
| 关闭主开关或退出应用 | 释放本应用的防休眠请求 |
| 合盖后重新打开电脑 | 检查截止时间；已到期的会话结束，不自动续期 |

如果 KeepingYouAwake 或其他应用也在阻止休眠，关闭醒着只会释放醒着自己的请求。

## 工作原理与边界

使用 macOS 自带的 `/usr/bin/caffeinate`：

- `-i` 阻止系统因空闲而休眠。
- 可选 `-d` 阻止显示器因空闲而关闭。
- 定时会话使用 `-t`；应用同时跟踪截止时间并在唤醒时校正显示。
- `-w <应用 PID>` 让 macOS 在应用进程退出后释放请求，包含强制退出的情况。

应用不会修改 `pmset` 系统设置，不需要管理员权限。它不会保证合盖运行，也不会阻止你主动选择「睡眠」。
屏幕常亮会增加耗电；用于下载、编译等任务时，可以只保持系统运行。

## 项目结构

```text
Sources/AwakeCore/   会话状态、截止时间、caffeinate 进程管理
Sources/StayAwake/   SwiftUI 面板、菜单栏入口、偏好与登录启动
Tests/              可注入时钟 / 进程替身的核心逻辑测试
Resources/          应用元数据
scripts/            构建、打包、测试与原创图标生成
```

GitHub Actions 在推送与 Pull Request 时执行测试并构建通用应用，产物位于对应运行的 Artifacts。
本地打包输出包含 `.zip` 和 SHA-256 校验文件。

## 致谢与许可

功能理念参考 [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake)，
采用同样的系统 `caffeinate` 能力。代码、面板和图标独立实现，详情见 [NOTICE.md](NOTICE.md)。

[MIT License](LICENSE)。

## 维护与发布新版本

1. 修改代码，并同步更新 `Resources/Info.plist` 的版本号与构建号。
2. 执行 `bash scripts/test.sh --integration` 与 `bash scripts/package.sh --universal`。
3. 提交到 `main`，再推送匹配版本号的标签，例如 `v1.0.1`。

`Publish Release` 工作流会核对版本、构建通用包并上传 ZIP 和 SHA-256 校验文件。
本地应用的「检查更新」读取正式 Release，**仅推送源码不会触发客户端升级**。
