import AppKit
import AwakeCore
import Combine
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    let session = SessionController(driver: CaffeinateDriver())
    @Published var durationMinutes: Int {
        didSet { defaults.set(durationMinutes, forKey: "durationMinutes") }
    }
    @Published var keepsDisplayAwake: Bool {
        didSet { defaults.set(keepsDisplayAwake, forKey: "keepsDisplayAwake") }
    }
    @Published var showCountdown: Bool {
        didSet { defaults.set(showCountdown, forKey: "showCountdown") }
    }
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published var settingsError: String?

    private let defaults: UserDefaults
    private var clock: AnyCancellable?
    private var changes: AnyCancellable?
    private var wakeObserver: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["durationMinutes": 30, "keepsDisplayAwake": false,
                                    "showCountdown": true])
        let savedDuration = defaults.integer(forKey: "durationMinutes")
        durationMinutes = (0...1440).contains(savedDuration) ? savedDuration : 30
        keepsDisplayAwake = defaults.bool(forKey: "keepsDisplayAwake")
        showCountdown = defaults.bool(forKey: "showCountdown")
        // The app always opens inactive; a stale session is never silently restored.
        changes = session.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, self.session.isActive else { return }
            self.session.refresh()
        }
        wakeObserver = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.session.refresh() }
    }

    var isActive: Bool { session.isActive }
    var launchAtLogin: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }
    var durationLabel: String {
        switch durationMinutes {
        case 0: return "无限时长"
        case let value where value % 60 == 0: return "\(value / 60) 小时"
        default: return "\(durationMinutes) 分钟"
        }
    }
    var timeLabel: String {
        guard isActive else { return durationLabel }
        return session.remainingSeconds.map(AwakeSession.formattedTime) ?? "无限时长"
    }
    var menuBarTitle: String {
        guard isActive, showCountdown, let seconds = session.remainingSeconds else { return "" }
        return AwakeSession.formattedTime(seconds)
    }

    func toggle() {
        if isActive { session.stop() } else { start() }
    }

    func start() {
        _ = session.start(duration: durationMinutes == 0 ? nil : Double(durationMinutes * 60),
                          keepsDisplayAwake: keepsDisplayAwake)
    }

    func selectDuration(_ minutes: Int) {
        guard (0...1440).contains(minutes) else { return }
        durationMinutes = minutes
        if isActive { start() }
    }

    func setDisplayAwake(_ enabled: Bool) {
        if session.setDisplayAwake(enabled) { keepsDisplayAwake = enabled }
    }

    func refreshSettings() { loginStatus = SMAppService.mainApp.status }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            settingsError = nil
        } catch {
            settingsError = "登录启动设置失败：\(error.localizedDescription)"
        }
        refreshSettings()
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
}
