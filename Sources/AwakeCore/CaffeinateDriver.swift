import Foundation

@MainActor
public protocol SleepPreventing: AnyObject {
    var isRunning: Bool { get }
    func start(configuration: CaffeinateConfiguration) throws
    func stop()
}

@MainActor
public final class CaffeinateDriver: SleepPreventing {
    private var process: Process?
    public var isRunning: Bool { process?.isRunning == true }

    public init() {}

    public func start(configuration: CaffeinateConfiguration) throws {
        let next = Process()
        next.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        next.arguments = try configuration.arguments()
        next.standardOutput = FileHandle.nullDevice
        next.standardError = FileHandle.nullDevice
        // Start first: if launching fails, the current session stays protected.
        try next.run()
        let previous = process
        process = next
        if previous?.isRunning == true { previous?.terminate() }
    }

    public func stop() {
        let previous = process
        process = nil
        if previous?.isRunning == true { previous?.terminate() }
    }
}
