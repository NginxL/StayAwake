# 开发指南

[English](DEVELOPMENT.md) · 简体中文 · [返回 README](../README.zh-CN.md)

StayAwake 使用 Swift Package Manager 构建，以 SwiftUI 实现界面、AppKit 提供菜单栏入口。防休眠能力来自 macOS 自带的 `caffeinate`，没有第三方包依赖。

## 环境与本地构建

需要 macOS 14 或更新版本、Swift 5.9 或更新版本。安装 Apple Command Line Tools 即可，无需完整 Xcode。

```bash
xcode-select --install # 已安装 Command Line Tools 时跳过。
git clone https://github.com/NginxL/StayAwake.git
cd StayAwake
bash scripts/build.sh
```

构建脚本按本机架构编译，生成 `dist/StayAwake.app`，并生成图标、打包更新辅助脚本和许可文件、签名应用。在 Finder 中打开即可使用。日常使用或设置登录启动前，先将应用放到 `/Applications` 或 `~/Applications` 等固定位置。

同时构建并打包两种架构：

```bash
bash scripts/package.sh --universal
```

产物包括 `dist/StayAwake.app`、`dist/StayAwake-<version>-universal.zip` 及配套的 `.zip.sha256` 文件。通用可执行文件包含 `arm64` 和 `x86_64`。

构建默认使用 **ad-hoc 本地签名，未经 Apple 公证**。设置 `CODESIGN_IDENTITY` 可改变构建脚本使用的签名身份，但不会执行公证。SHA-256 校验或有效的 ad-hoc 签名不等同于 Apple Developer ID 发布者身份认证。脚本不会修改 Gatekeeper 或其他系统安全设置。

## 测试

```bash
bash scripts/test.sh
```

测试通过 `AwakeChecks` 可执行程序运行，使用可注入的时钟和模拟进程驱动。请使用此脚本，而非 `swift test`；项目未定义 XCTest 测试目标。核心检查覆盖会话到期、时长调整、屏幕模式切换、启动失败、进程异常退出、时间格式和版本比较。

可选的 macOS 集成检查：

```bash
bash scripts/test.sh --integration
```

集成检查会短暂创建**真实的防休眠请求**，并通过 `pmset -g assertions` 查看。检查范围包括屏幕控制、超时与停止，以及专用测试进程被强制终止后的请求释放；不会强制退出已安装的应用。

发布前还应实际验证面板、菜单栏操作、Dock 入口、登录启动设置和更新流程。核心测试程序不自动覆盖这些界面与安装路径。

## 实现结构

| 目录 | 职责 |
| --- | --- |
| `Sources/AwakeCore/` | 会话状态、截止时间、时间格式、版本比较及 `caffeinate` 驱动 |
| `Sources/StayAwake/` | SwiftUI 面板、AppKit 菜单栏与 Dock 行为、偏好保存、登录启动和更新 |
| `Tests/AwakeCoreTests/` | 独立核心检查与可选集成检查 |
| `Resources/` | 应用元数据与更新安装辅助脚本 |
| `scripts/` | 构建、测试、打包与图标生成脚本 |
| `.github/workflows/` | CI 构建与标签发布流程 |

`CaffeinateConfiguration` 为 `/usr/bin/caffeinate` 生成以下参数：

| 参数 | 作用 |
| --- | --- |
| `-i` | 阻止系统因空闲而休眠 |
| `-d` | 可选：阻止显示器因空闲而关闭 |
| `-t <秒数>` | 限制定时会话的持续时间 |
| `-w <应用 PID>` | 应用进程退出后释放请求，包括强制退出 |

`SessionController` 跟踪截止时间，并在 Mac 唤醒后刷新状态。调整时长会重新计时；切换屏幕模式保留当前截止时间。驱动先启动替代进程，再终止原进程，因此新进程启动失败时可以保留现有会话。应用每次启动时，防休眠默认关闭。

应用不会修改 `pmset` 配置，不会覆盖用户主动选择的睡眠命令，也不保证笔记本合盖后继续运行。

## 更新实现

检查和安装更新均由用户发起。`AppUpdater` 读取 `NginxL/StayAwake` 最新的正式 Release，比较三段式版本号，并查找以下资产：

```text
StayAwake-<version>-universal.zip
StayAwake-<version>-universal.zip.sha256
```

更新器在暂存应用前检查资产地址、校验和、应用标识、版本号、可执行文件及代码签名完整性。安装要求应用位于有写入权限的 `/Applications` 或 `~/Applications`。辅助脚本等待当前应用退出，替换后重新打开；正在运行的防休眠会话会随之结束。

上一版本保留在安装目录旁的 `.StayAwake-previous.app`。替换失败或启动命令返回错误时，辅助脚本会尝试恢复旧版本。**更新器不会检测启动后的健康状态，也不会因后续崩溃自动回滚。** 下载或校验失败发生在替换前，已安装应用会被保留。

## 发布版本

1. 将 `Resources/Info.plist` 中的 `CFBundleShortVersionString` 更新为下一版 `主版本.次版本.修订版本`，并递增 `CFBundleVersion`。
2. 执行 `bash scripts/test.sh --integration` 和 `bash scripts/package.sh --universal`，完成上述界面与更新流程验证。
3. 将发布改动提交到 `main`，再创建并推送对应标签。例如，版本 `1.0.1` 必须对应 `v1.0.1`。
4. 检查 **Publish Release** 工作流，并确认已发布的 GitHub Release 同时包含 ZIP 和校验文件。

[Build macOS App](../.github/workflows/build.yml) 在推送到 `main`、创建或更新 Pull Request、手动触发时运行核心检查并打包通用应用。其可下载的工作流产物与 GitHub Release 资产是不同的发布渠道。

[Publish Release](../.github/workflows/release.yml) 在推送 `v*` 标签时运行，也可指定已有标签手动触发。它核对标签与 `CFBundleShortVersionString`，运行核心检查、构建通用包，并创建带安装资产的 Release。如果 Release 已存在，工作流会保留原资产并跳过发布。

**仅推送源码或生成 CI 产物，不会让已安装客户端发现更新。** 较新的正式 Release 必须包含名称正确的两份资产。当前更新器接受可选 `v` 前缀的纯数字三段式版本号，不支持预发布后缀。
