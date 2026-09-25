import Combine
import Foundation

@MainActor
public final class SessionController: ObservableObject {
    @Published public private(set) var session: AwakeSession?
    @Published public private(set) var keepsDisplayAwake = false
    @Published public private(set) var currentTime: Date
    @Published public private(set) var message = "准备好了，给 Mac 续一杯。"
    @Published public private(set) var errorMessage: String?

    private let driver: SleepPreventing
    private let now: () -> Date
    private let ownerPID: Int32

    public var isActive: Bool { session != nil }
    public var remainingSeconds: Int? { session?.remainingSeconds(at: currentTime) }

    public init(driver: SleepPreventing, ownerPID: Int32 = ProcessInfo.processInfo.processIdentifier,
                now: @escaping () -> Date = Date.init) {
        self.driver = driver
        self.ownerPID = ownerPID
        self.now = now
        currentTime = now()
    }

    @discardableResult
    public func start(duration: TimeInterval?, keepsDisplayAwake: Bool) -> Bool {
        let time = now()
        let config = CaffeinateConfiguration(keepsDisplayAwake: keepsDisplayAwake,
                                            timeout: duration, ownerPID: ownerPID)
        do {
            _ = try config.arguments()
            try driver.start(configuration: config)
            self.keepsDisplayAwake = keepsDisplayAwake
            currentTime = time
            session = AwakeSession(startedAt: time, duration: duration)
            errorMessage = nil
            message = "保持清醒，安心做你的事。"
            return true
        } catch {
            errorMessage = "未能开启防休眠：\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    public func setDisplayAwake(_ enabled: Bool) -> Bool {
        refresh()
        guard let session else {
            keepsDisplayAwake = enabled
            return true
        }
        do {
            // A screen setting change must not restart or extend the timer.
            let remaining = session.deadline.map { $0.timeIntervalSince(now()) }
            try driver.start(configuration: .init(keepsDisplayAwake: enabled,
                                                  timeout: remaining, ownerPID: ownerPID))
            keepsDisplayAwake = enabled
            errorMessage = nil
            return true
        } catch {
            errorMessage = "未能更新屏幕设置：\(error.localizedDescription)"
            return false
        }
    }

    public func stop(message: String = "已暂停，Mac 将按系统设置休眠。") {
        driver.stop()
        session = nil
        currentTime = now()
        self.message = message
        errorMessage = nil
    }

    public func refresh() {
        currentTime = now()
        guard let session else { return }
        if session.isExpired(at: currentTime) {
            stop(message: "时间到了，Mac 可以休息了。")
        } else if !driver.isRunning {
            stop(message: "防休眠已停止。")
            errorMessage = "系统防休眠进程已结束，请重新开启。"
        }
    }
}
