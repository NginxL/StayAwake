<p align="center">
  <img src="docs/AppIcon.png" width="96" height="96" alt="醒着的咖啡杯图标" />
</p>

<h1 align="center">醒着 · StayAwake</h1>

<p align="center">让 Mac 保持清醒，让屏幕按需休息。</p>

<p align="center">
  <a href="https://github.com/NginxL/StayAwake/releases/latest"><img src="https://img.shields.io/github/v/release/NginxL/StayAwake?color=187c68" alt="最新版本" /></a>
  <a href="https://github.com/NginxL/StayAwake/actions/workflows/build.yml"><img src="https://github.com/NginxL/StayAwake/actions/workflows/build.yml/badge.svg" alt="构建状态" /></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-555555" alt="需要 macOS 14 或更新版本" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT 许可证" /></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <a href="https://github.com/NginxL/StayAwake/releases/latest"><strong>下载 macOS 版</strong></a> ·
  <a href="#安装">安装说明</a> ·
  <a href="https://github.com/NginxL/StayAwake/issues">反馈问题</a>
</p>

醒着是一款原生 macOS 菜单栏防休眠工具，适合下载、编译、演示等需要电脑持续运行的场景。选择时长并开启，即可让 Mac 保持运行，屏幕是否常亮则由你独立控制。应用使用 Swift 和 SwiftUI 构建，底层调用系统自带的 `caffeinate`，没有第三方运行时依赖。

**兼容性：** macOS 14 或更新版本 · 通用安装包同时支持 Apple Silicon 与 Intel。目前 **App 界面为简体中文**，项目文档提供中英文版本。

## 界面预览

<table>
  <tr>
    <th align="center">一眼看清剩余时间</th>
    <th align="center">偏好设置与版本更新</th>
  </tr>
  <tr>
    <td align="center" valign="top"><a href="docs/images/session.png"><img src="docs/images/session.png" width="360" alt="醒着正在运行 30 分钟会话，显示倒计时、进度条、预设时长与屏幕常亮开关" /></a></td>
    <td align="center" valign="top"><a href="docs/images/settings.png"><img src="docs/images/settings.png" width="360" alt="醒着的设置面板，包含菜单栏倒计时、登录时打开、手动检查更新，并显示 v1.0.0 已是最新版本" /></a></td>
  </tr>
  <tr>
    <td valign="top">30 分钟会话运行中，倒计时与进度条同步显示。关闭<strong>保持屏幕常亮</strong>后，Mac 仍可保持运行，屏幕可以休息。</td>
    <td valign="top">展开<strong>设置</strong>，即可调整菜单栏倒计时、登录启动，并<strong>检查更新</strong>。图中为无限时长会话。</td>
  </tr>
</table>

<p align="center"><sub>截图来自 StayAwake v1.0.0 实际运行界面，点击图片可查看原图。</sub></p>

## 功能

| 功能 | 说明 |
| --- | --- |
| 快捷操作 | 从菜单栏或 Dock 打开面板；右键点击菜单栏图标，可直接开启或关闭防休眠。 |
| 灵活计时 | 支持无限时长，15 / 30 / 45 分钟及 1 / 4 / 8 小时预设，也可自定义 1–1440 分钟。 |
| 进度可见 | 面板展示倒计时与进度条，可选在菜单栏显示剩余时间。 |
| 独立控制屏幕 | 保持系统运行的同时，允许屏幕休息，也可让屏幕一起常亮。 |
| 可选登录启动 | 登录时自动打开 App；防休眠仍需手动开启。 |

## 安装

1. 从[最新版本页面](https://github.com/NginxL/StayAwake/releases/latest)下载 `StayAwake-<版本>-universal.zip`。
2. 解压后，将 `StayAwake.app` 移入 `/Applications` 或 `~/Applications`。
3. 打开应用，通过菜单栏咖啡杯图标或 Dock 中的「醒着」进入面板。

需要固定 Dock 入口时，右键点击图标，选择「**选项 → 在程序坞中保留**」。请保留应用文件名 `StayAwake.app`，以便使用内置更新。

> **签名状态：** 当前安装包采用 ad-hoc 签名，尚未经过 Apple Developer ID 签名或公证。macOS 可能阻止打开下载的应用；也可以在本机[从源码构建](docs/DEVELOPMENT.zh-CN.md#环境与本地构建)。构建脚本不会修改 Gatekeeper 设置。

## 使用

选择持续时间，再打开右上角主开关。选择「**∞ / 不限**」表示不自动到期，「**自定义**」可输入分钟数。需要提前结束时，关闭主开关即可。

| 操作 | 行为 |
| --- | --- |
| 运行中更改时长 | 从当前时间按新时长重新计时。 |
| 切换「保持屏幕常亮」 | 仅改变屏幕行为，保留会话原有截止时间。 |
| 到期、关闭主开关或退出 | 释放醒着自己的防休眠请求。 |
| 截止时间后唤醒 Mac | 结束已过期会话，不自动延长时长。 |

## 更新

打开「**设置 → 检查更新**」，发现新版本后点击「**下载并安装**」。检查和安装均由用户手动发起，应用不会静默升级。

更新器从本仓库 GitHub Releases 下载通用安装包，检查 SHA-256、应用标识、版本和代码签名完整性，然后替换并重新打开应用。**更新会结束当前会话；重新打开后，防休眠默认关闭。** 应用须位于有写入权限的 `/Applications` 或 `~/Applications` 目录。

上一版本保留在应用旁的 `.StayAwake-previous.app`，可用于手动恢复。更新器不会监测新版启动后的崩溃。校验和与 ad-hoc 签名检查用于发现完整性问题，不能验证开发者身份。具体机制见[更新实现](docs/DEVELOPMENT.zh-CN.md#更新实现)。

## 隐私与休眠行为

**需要联网吗？** 防休眠功能完全离线工作，没有统计上报。手动检查或下载更新时会访问 GitHub；源码链接会在浏览器中打开 GitHub。

**为什么 Mac 还会锁屏？** 锁屏与系统休眠是两回事。关闭「保持屏幕常亮」时，屏幕可以关闭，Mac 仍可继续运行。醒着不会禁用屏幕保护程序、自动锁屏或密码要求；即使开启屏幕常亮，也不等于开启了「防锁屏」。

**合上盖子后还能运行吗？** 醒着阻止的是「空闲休眠」，不保证合盖运行，也不会覆盖主动选择「睡眠」的行为；这些仍由 macOS 管理。

**会修改系统电源设置吗？** 不会。应用通过 `caffeinate` 创建临时请求，不修改 `pmset` 设置。关闭时只释放自己的请求，其他应用仍可能阻止休眠。保持屏幕常亮会增加耗电。

## 开发与贡献

在 macOS 14+ 上安装提供 Swift 5.9 或更新版本的 Apple Command Line Tools，即可本地构建：

```bash
git clone https://github.com/NginxL/StayAwake.git
cd StayAwake
bash scripts/build.sh
```

构建产物位于 `dist/StayAwake.app`。测试、架构、通用安装包和版本发布说明见[开发指南](docs/DEVELOPMENT.zh-CN.md)。

欢迎提交 Issue 和 Pull Request。报告问题时，请附上应用版本、macOS 版本、Mac 架构、复现步骤、预期行为与实际结果，并移除日志或截图中的个人信息。修改文档时，请保持中英文内容一致。

## 许可证

项目采用 [MIT 许可证](LICENSE)。
