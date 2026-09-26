import AppKit
import AwakeUI
import Combine
import SwiftUI

@main
struct StayAwakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanelController?
    private var changes: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        panel = MenuBarPanelController(rootView: PanelView(model: model))
        changes = model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
        updateStatusItem()

        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin { showPanel() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { model.session.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            model.toggle()
            return
        }
        let location = NSEvent.mouseLocation
        guard let buttonFrame else { return }
        model.refreshSettings()
        panel?.toggle(at: location, buttonFrame: buttonFrame)
    }

    private func showPanel() {
        let location = NSEvent.mouseLocation
        guard let buttonFrame else { return }
        model.refreshSettings()
        panel?.show(at: location, buttonFrame: buttonFrame)
    }

    private var buttonFrame: NSRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let name = model.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "醒着")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.title = model.menuBarTitle.isEmpty ? "" : " \(model.menuBarTitle)"
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.toolTip = model.isActive ? "醒着：已开启 · 右键暂停" : "醒着：未开启 · 右键开启"
        button.setAccessibilityLabel(button.toolTip)
    }
}
