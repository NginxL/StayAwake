import AppKit
import AwakeCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var model: AppModel
    @StateObject private var updater = AppUpdater()
    @State private var showSettings = false
    @State private var showCustom = false
    @State private var customMinutes = "90"
    @State private var customError: String?

    private let accent = Color(red: 0.13, green: 0.48, blue: 0.39)
    private let presets = [0, 15, 30, 45, 60, 240, 480]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            statusCard
            durationSection
            Divider().opacity(0.55)
            Toggle(isOn: Binding(get: { model.keepsDisplayAwake }, set: model.setDisplayAwake)) {
                settingLabel("保持屏幕常亮", detail: "关闭后仍保持 Mac 运行", symbol: "display")
            }
            .toggleStyle(.switch)
            .accessibilityLabel("保持屏幕常亮")
            .accessibilityIdentifier("keepDisplayAwake")

            if showSettings { settingsSection }
            if let error = model.session.errorMessage ?? model.settingsError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            footer
        }
        .padding(22)
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .onAppear { model.refreshSettings() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 23)).foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("醒着").font(.system(size: 20, weight: .semibold))
                Text("STAY AWAKE").font(.system(size: 9, weight: .medium, design: .rounded))
                    .tracking(1.8).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("防休眠", isOn: Binding(get: { model.isActive }, set: { _ in model.toggle() }))
                .labelsHidden().toggleStyle(.switch).controlSize(.large)
                .accessibilityLabel("防休眠开关")
                .accessibilityIdentifier("awakeToggle")
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(model.isActive ? accent : Color.secondary.opacity(0.55)).frame(width: 6, height: 6)
                Text(model.isActive ? "正在保持清醒" : "当前未开启")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: model.isActive ? "sun.max" : "moon")
                    .font(.system(size: 16)).foregroundStyle(accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(model.timeLabel)
                    .font(.system(size: 35, weight: .medium, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("sessionTime")
                if model.isActive && model.session.remainingSeconds != nil {
                    Text("后自动结束").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Text(model.session.message).font(.system(size: 12)).foregroundStyle(.secondary)
            if let session = model.session.session, session.deadline != nil {
                ProgressView(value: 1 - session.progress(at: model.session.currentTime))
                    .tint(accent)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(model.isActive ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(accent.opacity(0.09)))
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("持续时间").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(showCustom ? "收起" : "自定义") {
                    showCustom.toggle()
                    customError = nil
                }
                .font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(accent)
            }
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { minutes in
                    Button { model.selectDuration(minutes) } label: {
                        VStack(spacing: 3) {
                            Text(minutes == 0 ? "∞" : String(minutes < 60 ? minutes : minutes / 60))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text(minutes == 0 ? "不限" : minutes < 60 ? "分钟" : "小时")
                                .font(.system(size: 9))
                        }
                        .frame(maxWidth: .infinity).frame(height: 51)
                        .foregroundStyle(model.durationMinutes == minutes ? Color.white : Color.primary)
                        .background(model.durationMinutes == minutes ? accent : Color.primary.opacity(0.055),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(minutes == 0 ? "无限时长" : "\(minutes) 分钟")
                    .accessibilityAddTraits(model.durationMinutes == minutes ? .isSelected : [])
                }
            }
            if showCustom {
                HStack {
                    TextField("1–1440", text: $customMinutes)
                        .textFieldStyle(.roundedBorder).frame(width: 88)
                        .accessibilityLabel("自定义分钟数")
                        .onSubmit(applyCustomDuration)
                    Text("分钟").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Button("应用", action: applyCustomDuration).buttonStyle(.bordered)
                }
                if let customError {
                    Text(customError).font(.system(size: 11)).foregroundStyle(.red)
                }
            }
            Text(model.isActive ? "更改时长后，将从现在重新计时。" : "选择时长后，打开右上角开关。")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Toggle(isOn: $model.showCountdown) {
                settingLabel("菜单栏倒计时", detail: "定时开启时显示剩余时间", symbol: "timer")
            }.toggleStyle(.switch)
            Toggle(isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin)) {
                settingLabel("登录时打开", detail: "打开 App 后，由你开启防休眠", symbol: "arrow.right.circle")
            }.toggleStyle(.switch)
            if model.loginStatus == .requiresApproval {
                Button("前往系统设置允许登录启动", action: model.openLoginSettings)
                    .font(.system(size: 11)).buttonStyle(.link)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("版本更新", systemImage: "arrow.down.circle")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    if updater.available != nil {
                        Button("下载并安装", action: updater.install)
                            .disabled(updater.isBusy)
                    } else {
                        Button("检查更新", action: updater.check)
                            .disabled(updater.isBusy)
                    }
                }
                Text(updater.statusText).font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("仅防止空闲休眠。合盖和主动选择“睡眠”仍由 macOS 管理。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                showSettings.toggle()
                model.refreshSettings()
            } label: { Label("设置", systemImage: "slider.horizontal.3") }
                .accessibilityIdentifier("settingsButton")
            Spacer()
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
            Link(destination: URL(string: "https://github.com/NginxL/StayAwake")!) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }.help("查看源码与使用说明")
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
            }.help("退出醒着").accessibilityLabel("退出醒着")
        }
        .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
    }

    private func settingLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 19).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func applyCustomDuration() {
        guard let value = Int(customMinutes.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...1440).contains(value) else {
            customError = "请输入 1–1440 之间的整数。"
            return
        }
        model.selectDuration(value)
        customError = nil
        showCustom = false
    }
}
