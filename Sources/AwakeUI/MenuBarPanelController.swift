import AppKit
import AwakeCore
import SwiftUI

@MainActor
private final class MenuBarPanel: NSPanel {
    var dismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { dismiss?() }
}

@MainActor
private final class SizingHostingController: NSHostingController<AnyView> {
    var sizeChanged: ((NSSize) -> Void)?
    override var preferredContentSize: NSSize {
        didSet { sizeChanged?(preferredContentSize) }
    }
}

/// A single, directly positioned window for every menu-bar copy and the Dock.
/// Placement is applied to the real window after activation, without a popover anchor.
@MainActor
public final class MenuBarPanelController {
    private var panel: MenuBarPanel?
    private let content: SizingHostingController
    private var anchor: MenuBarAnchor?
    private var screenFrame: NSRect?
    private var visibleFrame: NSRect?
    private var openedAt: TimeInterval = 0
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    public var isVisible: Bool { panel?.isVisible == true }
    public var frame: NSRect { panel?.frame ?? .zero }
    public var displayFrame: NSRect? { panel?.screen?.frame }
    public var isOnActiveSpace: Bool { panel?.isOnActiveSpace == true }
    public var windowNumber: Int? { panel?.windowNumber }

    public init<Content: View>(rootView: Content) {
        content = SizingHostingController(rootView: AnyView(rootView))
        content.sizingOptions = [.preferredContentSize]
        content.sizeChanged = { [weak self] _ in
            // Hosting updates preferred size during layout. Resizing the window
            // inside that pass can leave the SwiftUI layer clipped to its old size.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.resize(to: self.content.preferredContentSize)
            }
        }

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.hide() } })
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.hide() } })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.processIdentifier == NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
            MainActor.assumeIsolated { self?.hide() }
        })
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        observers.forEach(NotificationCenter.default.removeObserver)
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }

    public func toggle(at location: NSPoint, buttonFrame: NSRect, screens: [NSScreen] = NSScreen.screens) {
        let clickedScreen = screens.first { $0.frame.contains(location) }
        if isVisible, isOnActiveSpace, screenFrame == clickedScreen?.frame {
            hide()
        } else {
            show(at: location, buttonFrame: buttonFrame, screens: screens)
        }
    }

    public func show(at location: NSPoint, buttonFrame: NSRect,
                     screens: [NSScreen] = NSScreen.screens) {
        guard let placement = MenuBarAnchor.resolve(mouseLocation: location, buttonFrame: buttonFrame,
                                                    screens: screens.map(\.frame)) else { hide(); return }
        hide()
        let screen = screens[placement.screenIndex]
        panel?.contentViewController = nil
        panel?.close()
        // Create the backing window on the requested display. Moving an existing
        // window's frame alone can retain its previous Space/display membership.
        let initialSize = content.preferredContentSize.width > 0 ? content.preferredContentSize : content.view.fittingSize
        let initialFrame = placement.panelFrame(contentSize: initialSize, visibleFrame: screen.visibleFrame)
        let localFrame = initialFrame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        let window = MenuBarPanel(contentRect: localFrame, styleMask: [.borderless],
                                  backing: .buffered, defer: false, screen: screen)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.level = .statusBar
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.title = "醒着"
        window.contentViewController = content
        content.view.wantsLayer = true
        content.view.layer?.cornerRadius = 16
        content.view.layer?.masksToBounds = true
        window.dismiss = { [weak self] in self?.hide() }
        panel = window
        anchor = placement
        screenFrame = screen.frame
        visibleFrame = screen.visibleFrame
        openedAt = ProcessInfo.processInfo.systemUptime
        NSApplication.shared.activate(ignoringOtherApps: true)
        content.view.layoutSubtreeIfNeeded()
        let preferred = content.preferredContentSize
        resize(to: preferred.width > 0 && preferred.height > 0 ? preferred : content.view.fittingSize)
        // The frame is set on the actual panel on every click, before ordering it.
        window.orderFrontRegardless()
        window.makeKey()
        installMonitors()
    }

    public func hide() {
        panel?.orderOut(nil)
        anchor = nil
        screenFrame = nil
        visibleFrame = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
    }

    private func resize(to size: NSSize) {
        guard size.width > 0, size.height > 0, let anchor, let visibleFrame, let panel else { return }
        let frame = anchor.panelFrame(contentSize: size, visibleFrame: visibleFrame)
        if panel.frame != frame { panel.setFrame(frame, display: panel.isVisible) }
    }

    private func installMonitors() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.window === self.panel, event.keyCode == 53 { self.hide(); return nil }
            } else if event.window !== self.panel {
                // Keep menu-bar mouse-down for the status item's mouse-up action.
                let point = NSEvent.mouseLocation
                let inMenuBar = NSScreen.screens.contains {
                    let menuHeight = max($0.frame.maxY - $0.visibleFrame.maxY, NSStatusBar.system.thickness)
                    return $0.frame.contains(point) && point.y >= $0.frame.maxY - menuHeight
                }
                if !inMenuBar { self.hide() }
            }
            return event
        }
        // Mouse-only monitoring does not require Accessibility/Input Monitoring.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // A delayed event from the opening click must not dismiss the new panel.
            guard let self, event.timestamp > self.openedAt else { return }
            self.hide()
        }
    }
}
