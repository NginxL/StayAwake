import AppKit

// A separate app is essential: a panel over its own full-screen window does not
// exercise the cross-application Space and activation behavior of a status item.
@main
@MainActor
final class FullScreenHost: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var report: URL!

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = FullScreenHost()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard CommandLine.arguments.count == 2 else { NSApp.terminate(nil); return }
        report = URL(fileURLWithPath: CommandLine.arguments[1])
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "StayAwake Full-Screen Fixture"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]
        window.delegate = self
        let label = NSTextField(labelWithString: "StayAwake full-screen check — this test window will close automatically.")
        label.frame = NSRect(x: 40, y: 280, width: 700, height: 40)
        window.contentView?.addSubview(label)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(command(_:)),
            name: Notification.Name("StayAwakePanelChecks.command"), object: report.path)
        DispatchQueue.main.async { self.window.toggleFullScreen(nil) }
        // Do not leave a fixture covering the user's desktop if the runner fails.
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { NSApp.terminate(nil) }
    }

    @objc private func command(_ notification: Notification) {
        if notification.userInfo?["action"] as? String == "windowed" {
            if window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
        } else if notification.userInfo?["action"] as? String == "finish" {
            NSApp.terminate(nil)
        }
    }

    private func record(fullScreen: Bool) {
        let value: [String: Any] = ["fullScreen": fullScreen, "windowNumber": window.windowNumber]
        if let data = try? JSONSerialization.data(withJSONObject: value) {
            try? data.write(to: report, options: .atomic)
        }
    }
    func windowDidEnterFullScreen(_ notification: Notification) { record(fullScreen: true) }
    func windowDidExitFullScreen(_ notification: Notification) { record(fullScreen: false) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
