import AppKit
import AwakeCore
import Combine
import SwiftUI

@main
struct StayAwakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var anchorWindow: NSWindow?
    private var presentedScreen: NSRect?
    private var changes: AnyCancellable?
    private var screenChanges: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover.behavior = .transient
        // Re-anchoring on another display must not race an old close animation.
        popover.animates = false
        popover.delegate = self
        let content = NSHostingController(rootView: PanelView(model: model))
        content.sizingOptions = [.preferredContentSize]
        popover.contentViewController = content
        popover.contentSize = content.view.fittingSize
        changes = model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
        updateStatusItem()
        screenChanges = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.popover.close() }

        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin { showPanel() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { model.session.stop() }

    @objc private func togglePanel() {
        let mouseLocation = NSEvent.mouseLocation
        if NSApp.currentEvent?.type == .rightMouseUp {
            model.toggle()
        } else if popover.isShown,
                  presentedScreen == NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })?.frame {
            popover.performClose(nil)
        } else {
            showPanel(at: mouseLocation)
        }
    }

    private func showPanel(at mouseLocation: NSPoint = NSEvent.mouseLocation) {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        // Capture the display before activation can change the active window/Space.
        let screens = NSScreen.screens
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        guard let placement = MenuBarAnchor.resolve(mouseLocation: mouseLocation,
                                                    buttonFrame: buttonFrame,
                                                    screens: screens.map(\.frame)) else { return }
        if popover.isShown { popover.close() }
        model.refreshSettings()

        let positioningView: NSView
        if placement.usesStatusButton {
            positioningView = button
        } else {
            let anchor = NSWindow(contentRect: placement.rect, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            anchor.isReleasedWhenClosed = false
            anchor.isOpaque = false
            anchor.backgroundColor = .clear
            anchor.hasShadow = false
            anchor.ignoresMouseEvents = true
            anchor.level = .statusBar
            anchor.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
            let view = NSView(frame: NSRect(origin: .zero, size: placement.rect.size))
            anchor.contentView = view
            anchor.orderFrontRegardless()
            anchorWindow = anchor
            positioningView = view
        }
        popover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .minY)
        guard popover.isShown else { clearAnchor(); return }
        presentedScreen = screens[placement.screenIndex].frame
        // Focus only after the popover has a visible anchor on the intended screen.
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) { clearAnchor() }

    private func clearAnchor() {
        anchorWindow?.orderOut(nil)
        anchorWindow = nil
        presentedScreen = nil
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
