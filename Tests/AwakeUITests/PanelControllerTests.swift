import AppKit
import AwakeUI
import SwiftUI

@MainActor
private final class FixtureModel: ObservableObject {
    @Published var height: CGFloat = 440
}

private struct FixtureView: View {
    @ObservedObject var model: FixtureModel
    var body: some View {
        Text("StayAwake panel integration check")
            .frame(width: 380, height: model.height)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

@MainActor
private final class TestAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private let status = NSTextField(labelWithString: "Ready — this check briefly opens a panel on each connected display.")

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 180),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "StayAwake Display Checks"
        window.delegate = self
        status.frame = NSRect(x: 24, y: 85, width: 470, height: 60)
        status.maximumNumberOfLines = 3
        window.contentView?.addSubview(status)
        let button = NSButton(title: "Run display checks", target: self, action: #selector(runTests(_:)))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 24, y: 25, width: 200, height: 36)
        window.contentView?.addSubview(button)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func runTests(_ sender: NSButton) {
        sender.isEnabled = false
        window.orderOut(nil)
        Task { @MainActor in
            await PanelControllerTests.runChecks()
            status.stringValue = "\(PanelControllerTests.assertions) assertions, \(PanelControllerTests.failures) failures. Results: .build/PanelChecks-results.json"
            window.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === window { NSApp.terminate(nil) }
    }

}

@main
@MainActor
struct PanelControllerTests {
    static var failures = 0
    static var assertions = 0
    static var failedChecks: [String] = []
    static var diagnostics: [[String: Any]] = []

    static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !value() { failures += 1; failedChecks.append(message); print("FAIL: \(message)") }
    }

    static func settle() async {
        // Yield to the real NSApplication event loop for drawing and window events.
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    static func waitForPresentation(_ controller: MenuBarPanelController) async {
        for _ in 0..<15 {
            await settle()
            if controller.isVisible, controller.isOnActiveSpace { return }
        }
    }

    static func main() {
        guard Bundle.main.bundleIdentifier == "io.github.nginxl.StayAwake.PanelChecks" else {
            print("Run bash scripts/build-ui-checks.sh, then launch .build/PanelChecks.app in an unlocked desktop session.")
            exit(2)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = TestAppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    static func runChecks() async {
        await settle()
        let screens = NSScreen.screens
        guard let first = screens.first else { print("FAIL: No connected display"); exit(1) }
        let staleButton = NSRect(x: first.frame.maxX - 200, y: first.frame.maxY - 24, width: 32, height: 24)
        let model = FixtureModel()
        let controller = MenuBarPanelController(rootView: FixtureView(model: model))
        defer { controller.hide() }

        // Exercise actual NSPanel visibility and placement, including the path
        // where the status item's window is on a different physical display.
        for screen in screens {
            let click = NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 10)
            controller.show(at: click, buttonFrame: staleButton)
            await waitForPresentation(controller)
            // Inspect only this test app's window in the WindowServer list.
            // Pixel rendering is checked separately in the actual application UI.
            let window = NSApp.windows.first { $0.windowNumber == controller.windowNumber }
            let info = window.flatMap {
                (CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID($0.windowNumber)) as? [[String: Any]])?.first
            }
            diagnostics.append(["display": screen.localizedName, "frame": NSStringFromRect(controller.frame),
                                "windowNumber": controller.windowNumber ?? -1, "appActive": NSApp.isActive,
                                "onActiveSpace": controller.isOnActiveSpace, "visible": controller.isVisible,
                                "occlusion": window?.occlusionState.rawValue ?? 0,
                                "onScreen": info?[kCGWindowIsOnscreen as String] as? Bool ?? false])
            expect(info?[kCGWindowIsOnscreen as String] as? Bool == true, "WindowServer includes the panel on screen")
            // Occlusion is diagnostic only: another app can cover a correctly
            // placed panel. The actual content is also inspected in the app UI.
            expect(controller.isVisible, "panel visible on \(screen.localizedName)")
            expect(controller.isOnActiveSpace, "panel on active Space")
            expect(controller.displayFrame == screen.frame, "panel belongs to requested display")
            expect(screen.visibleFrame.contains(controller.frame), "panel inside visible display bounds")
            expect(controller.frame.height == 440, "initial content height")

            let top = controller.frame.maxY
            model.height = min(700, screen.visibleFrame.height - 80)
            await settle()
            expect(controller.frame.height == model.height, "expanded content resizes real window")
            expect(window?.contentView?.frame.height == model.height, "hosting view grows with window")
            expect(window?.contentView?.layer?.bounds.height == model.height, "hosting layer grows with window")
            expect(controller.frame.maxY == top, "expansion keeps menu-bar alignment")
            model.height = 440
            await settle()
            expect(controller.frame.height == 440, "collapsed content restores height")
            controller.toggle(at: click, buttonFrame: staleButton)
            expect(!controller.isVisible, "same-display toggle closes panel")
            controller.toggle(at: click, buttonFrame: staleButton)
            await waitForPresentation(controller)
            expect(controller.isVisible, "same-display toggle reopens panel")
            print("Checked: \(screen.localizedName), frame=\(controller.frame)")
        }

        for screen in screens.reversed() {
            controller.show(at: NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 10),
                            buttonFrame: staleButton)
            await waitForPresentation(controller)
            expect(controller.isVisible && controller.displayFrame == screen.frame,
                   "visible panel switches to requested display")
        }
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        expect(!controller.isVisible, "display reconfiguration dismisses panel")
        print("\(screens.count) physical displays, \(assertions) assertions, \(failures) failures")
        let report: [String: Any] = ["completedAt": ISO8601DateFormatter().string(from: Date()),
                                     "displays": screens.map(\.localizedName), "assertions": assertions,
                                     "failures": failures, "failedChecks": failedChecks, "diagnostics": diagnostics]
        let output = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("PanelChecks-results.json")
        do {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic)
        } catch { print("Could not write UI test results: \(error)"); failures += 1 }
    }
}
