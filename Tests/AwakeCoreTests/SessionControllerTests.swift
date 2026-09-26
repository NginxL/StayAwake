import Foundation
import CoreGraphics
import AwakeCore
import Darwin

@MainActor
private final class FakeDriver: SleepPreventing {
    var isRunning = false
    var configurations: [CaffeinateConfiguration] = []
    var stopCount = 0
    var failsToStart = false

    func start(configuration: CaffeinateConfiguration) throws {
        if failsToStart { throw CocoaError(.executableNotLoadable) }
        configurations.append(configuration)
        isRunning = true
    }
    func stop() { isRunning = false; stopCount += 1 }
}

@main
@MainActor
struct SessionControllerTests {
    static var failures = 0
    static var assertions = 0

    static func main() throws {
        if CommandLine.arguments.contains("--hold-awake") {
            let driver = CaffeinateDriver()
            try driver.start(configuration: .init(keepsDisplayAwake: false, timeout: nil,
                                                  ownerPID: ProcessInfo.processInfo.processIdentifier))
            withExtendedLifetime(driver) { RunLoop.main.run() }
            return
        }
        let tests = Self()
        tests.testExpiryReleasesProcessAndClearsSession()
        tests.testChangingDisplayKeepsOriginalDeadline()
        tests.testReplacingDurationRestartsFromCurrentTime()
        tests.testIndefiniteSessionDoesNotExpire()
        tests.testFailedStartDoesNotClaimToBeActive()
        tests.testFailedReplacementPreservesCurrentSession()
        tests.testUnexpectedProcessExitIsReported()
        tests.testWakeAfterDeadlineDoesNotRestartExpiredSession()
        tests.testInvalidDurationDoesNotReplaceSession()
        try tests.testProcessArgumentsIncludeOwnerAndOptionalDisplayAndTimeout()
        tests.testUnsafeTimeoutsAndInvalidOwnerAreRejected()
        tests.testTimeFormattingAndProgressAtBoundaries()
        tests.testSemanticVersionComparison()
        tests.testMenuBarAnchorUsesClickedDisplayInsteadOfStaleButtonWindow()
        tests.testMenuBarAnchorHandlesNegativeAndVerticalScreenOrigins()
        tests.testMenuBarAnchorKeepsNativeButtonOnItsOwnDisplay()
        tests.testDockAnchorStaysWithinTheSelectedDisplay()
        tests.testMenuBarAnchorHandlesMissingDisplays()
        var scenarioCount = 18
        if CommandLine.arguments.contains("--integration") {
            try tests.testRealSystemAssertionsAndTimeout()
            try tests.testForcedOwnerExitReleasesAssertions()
            scenarioCount += 2
        }
        print("\(scenarioCount) scenarios, \(assertions) assertions, \(failures) failures")
        if failures != 0 { exit(1) }
    }

    private func check(_ condition: Bool, file: StaticString, line: UInt) {
        Self.assertions += 1
        if !condition {
            Self.failures += 1
            print("FAIL \(file):\(line)")
        }
    }

    private func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
        check(value, file: file, line: line)
    }
    private func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
        check(!value, file: file, line: line)
    }
    private func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T,
                                             file: StaticString = #filePath, line: UInt = #line) {
        check(lhs == rhs, file: file, line: line)
    }
    private func expectNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
        check(value == nil, file: file, line: line)
    }
    private func expectNotNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
        check(value != nil, file: file, line: line)
    }
    private func expectThrows<T>(_ expression: @autoclosure () throws -> T,
                                          file: StaticString = #filePath, line: UInt = #line) {
        do { _ = try expression(); check(false, file: file, line: line) }
        catch { check(true, file: file, line: line) }
    }
    @MainActor func testExpiryReleasesProcessAndClearsSession() {
        let driver = FakeDriver()
        var time = Date(timeIntervalSince1970: 1000)
        let controller = SessionController(driver: driver, now: { time })
        expectTrue(controller.start(duration: 60, keepsDisplayAwake: false))
        time.addTimeInterval(59.1)
        controller.refresh()
        expectEqual(controller.remainingSeconds, 1)
        expectTrue(controller.isActive)
        time.addTimeInterval(0.9)
        controller.refresh()
        expectFalse(controller.isActive)
        expectFalse(driver.isRunning)
        expectEqual(driver.stopCount, 1)
        expectNil(controller.errorMessage)
    }

    @MainActor func testChangingDisplayKeepsOriginalDeadline() {
        let driver = FakeDriver()
        var time = Date(timeIntervalSince1970: 1000)
        let controller = SessionController(driver: driver, now: { time })
        controller.start(duration: 900, keepsDisplayAwake: false)
        let deadline = controller.session?.deadline
        time.addTimeInterval(120)
        expectTrue(controller.setDisplayAwake(true))
        expectEqual(controller.session?.deadline, deadline)
        expectEqual(driver.configurations.last?.timeout, 780)
        expectTrue(controller.keepsDisplayAwake)
    }

    @MainActor func testReplacingDurationRestartsFromCurrentTime() {
        let driver = FakeDriver()
        var time = Date(timeIntervalSince1970: 1000)
        let controller = SessionController(driver: driver, now: { time })
        controller.start(duration: 60, keepsDisplayAwake: false)
        time.addTimeInterval(30)
        controller.start(duration: 120, keepsDisplayAwake: false)
        expectEqual(controller.remainingSeconds, 120)
        expectEqual(controller.session?.deadline, time.addingTimeInterval(120))
    }

    @MainActor func testIndefiniteSessionDoesNotExpire() {
        let driver = FakeDriver()
        var time = Date(timeIntervalSince1970: 1000)
        let controller = SessionController(driver: driver, now: { time })
        controller.start(duration: nil, keepsDisplayAwake: false)
        time.addTimeInterval(100_000)
        controller.refresh()
        expectTrue(controller.isActive)
        expectNil(controller.remainingSeconds)
        expectNil(driver.configurations.last?.timeout)
        controller.stop()
        expectFalse(driver.isRunning)
    }

    @MainActor func testFailedStartDoesNotClaimToBeActive() {
        let driver = FakeDriver()
        driver.failsToStart = true
        let controller = SessionController(driver: driver)
        expectFalse(controller.start(duration: 60, keepsDisplayAwake: false))
        expectFalse(controller.isActive)
        expectNotNil(controller.errorMessage)
    }

    @MainActor func testFailedReplacementPreservesCurrentSession() {
        let driver = FakeDriver()
        let controller = SessionController(driver: driver)
        controller.start(duration: 60, keepsDisplayAwake: false)
        let original = controller.session
        driver.failsToStart = true
        expectFalse(controller.start(duration: 120, keepsDisplayAwake: true))
        expectEqual(controller.session, original)
        expectFalse(controller.keepsDisplayAwake)
        expectTrue(driver.isRunning)
        expectFalse(controller.setDisplayAwake(true))
        expectEqual(controller.session, original)
        expectFalse(controller.keepsDisplayAwake)
    }

    @MainActor func testUnexpectedProcessExitIsReported() {
        let driver = FakeDriver()
        let controller = SessionController(driver: driver)
        controller.start(duration: nil, keepsDisplayAwake: false)
        driver.isRunning = false
        controller.refresh()
        expectFalse(controller.isActive)
        expectNotNil(controller.errorMessage)
    }

    @MainActor func testWakeAfterDeadlineDoesNotRestartExpiredSession() {
        let driver = FakeDriver()
        var time = Date(timeIntervalSince1970: 1000)
        let controller = SessionController(driver: driver, now: { time })
        controller.start(duration: 60, keepsDisplayAwake: false)
        time.addTimeInterval(3600)
        driver.isRunning = false
        controller.refresh()
        expectFalse(controller.isActive)
        expectNil(controller.errorMessage)
        expectEqual(driver.configurations.count, 1)
    }

    @MainActor func testInvalidDurationDoesNotReplaceSession() {
        let driver = FakeDriver()
        let controller = SessionController(driver: driver)
        controller.start(duration: 60, keepsDisplayAwake: false)
        let original = controller.session
        expectFalse(controller.start(duration: 0, keepsDisplayAwake: false))
        expectEqual(controller.session, original)
        expectEqual(driver.configurations.count, 1)
    }

    func testProcessArgumentsIncludeOwnerAndOptionalDisplayAndTimeout() throws {
        expectEqual(try CaffeinateConfiguration(keepsDisplayAwake: false, timeout: nil, ownerPID: 42)
            .arguments(), ["-i", "-w", "42"])
        expectEqual(try CaffeinateConfiguration(keepsDisplayAwake: true, timeout: 1.2, ownerPID: 42)
            .arguments(), ["-i", "-d", "-t", "2", "-w", "42"])
    }

    func testUnsafeTimeoutsAndInvalidOwnerAreRejected() {
        for timeout in [0.0, -1, .nan, .infinity, 86_401] {
            expectThrows(try CaffeinateConfiguration(keepsDisplayAwake: false,
                                                            timeout: timeout, ownerPID: 42).arguments())
        }
        expectThrows(try CaffeinateConfiguration(keepsDisplayAwake: false,
                                                        timeout: nil, ownerPID: 0).arguments())
    }

    func testTimeFormattingAndProgressAtBoundaries() {
        expectEqual(AwakeSession.formattedTime(59), "00:59")
        expectEqual(AwakeSession.formattedTime(3600), "1:00:00")
        expectEqual(AwakeSession.formattedTime(-1), "00:00")
        let start = Date(timeIntervalSince1970: 1000)
        let session = AwakeSession(startedAt: start, duration: 60)
        expectEqual(session.progress(at: start.addingTimeInterval(-1)), 0)
        expectEqual(session.progress(at: start.addingTimeInterval(30)), 0.5)
        expectEqual(session.progress(at: start.addingTimeInterval(61)), 1)
    }

    private func output(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    func testSemanticVersionComparison() {
        expectTrue(AppVersion("1.10.0")! > AppVersion("1.9.9")!)
        expectTrue(AppVersion("2.0.0")! > AppVersion("1.99.99")!)
        expectEqual(AppVersion("v1.0.0"), AppVersion("1.0.0"))
        for invalid in ["1.0", "1.0.0-beta", "-1.0.0", "1..0", "../1.0.0", "v1.0.0; open /", "1.0.0.0"] {
            expectNil(AppVersion(invalid))
        }
    }

    func testMenuBarAnchorUsesClickedDisplayInsteadOfStaleButtonWindow() {
        let screens = [CGRect(x: 0, y: 0, width: 1728, height: 1117),
                       CGRect(x: 1728, y: 0, width: 2560, height: 1440)]
        let button = CGRect(x: 1300, y: 1080, width: 36, height: 37)
        let location = CGPoint(x: 3900, y: 1425)
        let anchor = MenuBarAnchor.resolve(mouseLocation: location, buttonFrame: button, screens: screens)!
        expectEqual(anchor.screenIndex, 1)
        expectFalse(anchor.usesStatusButton)
        expectEqual(anchor.rect.midX, location.x)
        expectEqual(anchor.rect.maxY, screens[1].maxY)
        expectTrue(screens[1].contains(anchor.rect))
    }

    func testMenuBarAnchorHandlesNegativeAndVerticalScreenOrigins() {
        let primary = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let button = CGRect(x: 1300, y: 1080, width: 36, height: 37)
        for display in [CGRect(x: -2560, y: -200, width: 2560, height: 1440),
                        CGRect(x: 100, y: 1117, width: 2560, height: 1440),
                        CGRect(x: -200, y: -1440, width: 2560, height: 1440)] {
            let location = CGPoint(x: display.midX, y: display.maxY - 10)
            let anchor = MenuBarAnchor.resolve(mouseLocation: location, buttonFrame: button,
                                               screens: [primary, display])!
            expectEqual(anchor.screenIndex, 1)
            expectEqual(anchor.rect.midX, location.x)
            expectTrue(display.contains(anchor.rect))
        }
    }

    func testMenuBarAnchorKeepsNativeButtonOnItsOwnDisplay() {
        let primary = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let external = CGRect(x: -2560, y: 0, width: 2560, height: 1440)
        let button = CGRect(x: -500, y: 1416, width: 70, height: 24)
        let anchor = MenuBarAnchor.resolve(mouseLocation: CGPoint(x: -480, y: 1428),
                                           buttonFrame: button, screens: [primary, external])!
        expectEqual(anchor.screenIndex, 1)
        expectTrue(anchor.usesStatusButton)
        expectEqual(anchor.rect, button)
    }

    func testDockAnchorStaysWithinTheSelectedDisplay() {
        let primary = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let external = CGRect(x: 1728, y: 0, width: 2560, height: 1440)
        let button = CGRect(x: 1300, y: 1080, width: 36, height: 37)
        let anchor = MenuBarAnchor.resolve(mouseLocation: CGPoint(x: 2500, y: 20),
                                           buttonFrame: button, screens: [primary, external])!
        expectEqual(anchor.screenIndex, 1)
        expectEqual(external.maxX - anchor.rect.midX, primary.maxX - button.midX)
        for x in [external.minX, external.maxX - 1] {
            let edge = MenuBarAnchor.resolve(mouseLocation: CGPoint(x: x, y: external.maxY - 1),
                                             buttonFrame: button, screens: [primary, external])!
            expectTrue(external.contains(edge.rect))
        }
    }

    func testMenuBarAnchorHandlesMissingDisplays() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let button = CGRect(x: 1300, y: 1080, width: 36, height: 37)
        let absentLocation = CGPoint(x: -500, y: 1400)
        let anchor = MenuBarAnchor.resolve(mouseLocation: absentLocation, buttonFrame: button,
                                           screens: [screen])!
        expectEqual(anchor.rect, button)
        expectTrue(anchor.usesStatusButton)
        expectNil(MenuBarAnchor.resolve(mouseLocation: absentLocation, buttonFrame: button, screens: []))
    }

    private func eventually(_ condition: () throws -> Bool) rethrows -> Bool {
        for _ in 0..<50 {
            if try condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    private func childPIDs(of owner: Int32) throws -> [Int32] {
        try output("/usr/bin/pgrep", ["-P", String(owner), "caffeinate"])
            .split(separator: "\n").compactMap { Int32($0) }
    }

    private func hasAssertion(pid: Int32, type: String) throws -> Bool {
        try output("/usr/bin/pmset", ["-g", "assertions"]).split(separator: "\n")
            .contains { $0.contains("pid \(pid)(caffeinate)") && $0.contains(type) }
    }

    func testRealSystemAssertionsAndTimeout() throws {
        let driver = CaffeinateDriver()
        defer { driver.stop() }
        let owner = ProcessInfo.processInfo.processIdentifier
        try driver.start(configuration: .init(keepsDisplayAwake: true, timeout: 15, ownerPID: owner))
        expectTrue(try eventually { try !childPIDs(of: owner).isEmpty })
        guard let first = try childPIDs(of: owner).first else { return }
        expectTrue(try eventually { try hasAssertion(pid: first, type: "PreventUserIdleSystemSleep") })
        expectTrue(try hasAssertion(pid: first, type: "PreventUserIdleDisplaySleep"))

        try driver.start(configuration: .init(keepsDisplayAwake: false, timeout: 2, ownerPID: owner))
        expectTrue(try eventually { try childPIDs(of: owner).count == 1 && !childPIDs(of: owner).contains(first) })
        guard let second = try childPIDs(of: owner).first else { return }
        expectTrue(try eventually { try hasAssertion(pid: second, type: "PreventUserIdleSystemSleep") })
        expectFalse(try hasAssertion(pid: second, type: "PreventUserIdleDisplaySleep"))
        expectTrue(eventually { !driver.isRunning })
        expectFalse(try hasAssertion(pid: second, type: "PreventUserIdleSystemSleep"))

        try driver.start(configuration: .init(keepsDisplayAwake: false, timeout: nil, ownerPID: owner))
        expectTrue(driver.isRunning)
        driver.stop()
        expectTrue(try eventually { try childPIDs(of: owner).isEmpty })
    }

    func testForcedOwnerExitReleasesAssertions() throws {
        let worker = Process()
        worker.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        worker.arguments = ["--hold-awake"]
        worker.standardOutput = FileHandle.nullDevice
        worker.standardError = FileHandle.nullDevice
        try worker.run()
        defer { if worker.isRunning { worker.terminate() } }
        expectTrue(try eventually { try !childPIDs(of: worker.processIdentifier).isEmpty })
        guard let child = try childPIDs(of: worker.processIdentifier).first else { return }
        expectTrue(try eventually { try hasAssertion(pid: child, type: "PreventUserIdleSystemSleep") })
        kill(worker.processIdentifier, SIGKILL)
        worker.waitUntilExit()
        expectTrue(try eventually { try !hasAssertion(pid: child, type: "PreventUserIdleSystemSleep") })
    }
}
