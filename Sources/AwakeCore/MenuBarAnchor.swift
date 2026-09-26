import Foundation
import CoreGraphics

/// All coordinates are AppKit screen points, including negative display origins.
public struct MenuBarAnchor: Equatable {
    public let screenIndex: Int
    public let rect: CGRect

    public static func resolve(mouseLocation: CGPoint, buttonFrame: CGRect,
                               screens: [CGRect]) -> MenuBarAnchor? {
        guard !screens.isEmpty else { return nil }
        let buttonCenter = CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)
        let buttonScreen = screens.firstIndex { $0.contains(buttonCenter) }
        let target = screens.firstIndex { $0.contains(mouseLocation) } ?? buttonScreen ?? 0
        if buttonScreen == target {
            return MenuBarAnchor(screenIndex: target, rect: buttonFrame)
        }

        // A mirrored status item's window can belong to a different display.
        // Use the click position instead of that window's frame in this case.
        let screen = screens[target]
        let width = min(max(buttonFrame.width, 1), screen.width)
        let height = min(max(buttonFrame.height, 1), screen.height)
        let isMenuBarClick = mouseLocation.y >= screen.maxY - height
        let rightInset = buttonScreen.map { screens[$0].maxX - buttonFrame.midX } ?? width / 2
        let centerX = isMenuBarClick ? mouseLocation.x : screen.maxX - rightInset
        let x = min(max(centerX - width / 2, screen.minX), screen.maxX - width)
        return MenuBarAnchor(screenIndex: target,
                             rect: CGRect(x: x, y: screen.maxY - height, width: width, height: height))
    }

    /// Position the real panel directly; no positioning window or popover is needed.
    public func panelFrame(contentSize: CGSize, visibleFrame: CGRect) -> CGRect {
        let width = min(max(contentSize.width, 1), visibleFrame.width)
        let height = min(max(contentSize.height, 1), visibleFrame.height)
        let x = min(max(rect.midX - width / 2, visibleFrame.minX), visibleFrame.maxX - width)
        let top = min(rect.minY - 6, visibleFrame.maxY)
        let y = min(max(top - height, visibleFrame.minY), visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
