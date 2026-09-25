import Foundation

public struct AwakeSession: Equatable {
    public let startedAt: Date
    public let deadline: Date?

    public init(startedAt: Date, duration: TimeInterval?) {
        self.startedAt = startedAt
        deadline = duration.map { startedAt.addingTimeInterval($0) }
    }

    public func remainingSeconds(at date: Date) -> Int? {
        deadline.map { max(0, Int(ceil($0.timeIntervalSince(date)))) }
    }

    public func isExpired(at date: Date) -> Bool {
        deadline.map { date >= $0 } ?? false
    }

    public func progress(at date: Date) -> Double {
        guard let deadline else { return 0 }
        let duration = deadline.timeIntervalSince(startedAt)
        guard duration > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(startedAt) / duration))
    }

    public static func formattedTime(_ seconds: Int) -> String {
        let value = max(0, seconds)
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

public struct CaffeinateConfiguration: Equatable {
    public let keepsDisplayAwake: Bool
    public let timeout: TimeInterval?
    public let ownerPID: Int32

    public init(keepsDisplayAwake: Bool, timeout: TimeInterval?, ownerPID: Int32) {
        self.keepsDisplayAwake = keepsDisplayAwake
        self.timeout = timeout
        self.ownerPID = ownerPID
    }

    public func arguments() throws -> [String] {
        guard ownerPID > 0 else { throw WakeError.invalidProcess }
        var result = ["-i"]
        if keepsDisplayAwake { result.append("-d") }
        if let timeout {
            guard timeout.isFinite, timeout > 0, timeout <= 86_400 else {
                throw WakeError.invalidDuration
            }
            result += ["-t", String(Int(ceil(timeout)))]
        }
        // macOS releases the assertions even if our app is force-quit.
        result += ["-w", String(ownerPID)]
        return result
    }
}

public enum WakeError: LocalizedError {
    case invalidDuration
    case invalidProcess

    public var errorDescription: String? {
        switch self {
        case .invalidDuration: return "请选择 1 分钟到 24 小时的时长。"
        case .invalidProcess: return "无法获取应用进程，请重新打开醒着。"
        }
    }
}
