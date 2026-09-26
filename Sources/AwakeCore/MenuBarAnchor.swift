import Foundation
import CoreGraphics

/// All coordinates are AppKit screen points, including negative display origins.
public struct MenuBarAnchor: Equatable {
    public let screenIndex: Int
    public let rect: CGRect
    public let usesStatusButton: Bool

    public static func resolve(mouseLocation: CGPoint, buttonFrame: CGRect,
                               screens: [CGRect]) -> MenuBarAnchor? {
        guard !screens.isEmpty else { return nil }
        let buttonCenter = CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)
        let buttonScreen = screens.firstIndex { $0.contains(buttonCenter) }
        let target = screens.firstIndex { $0.contains(mouseLocation) } ?? buttonScreen ?? 0
        if buttonScreen == target {
            return MenuBarAnchor(screenIndex: target, rect: buttonFrame, usesStatusButton: true)
        }

        // macOS may report the status item's window on a different display from
        // the clicked menu-bar copy. Anchor a visible view on the clicked screen.
        let screen = screens[target]
        let width = min(max(buttonFrame.width, 1), screen.width)
        let height = min(max(buttonFrame.height, 1), screen.height)
        let isMenuBarClick = mouseLocation.y >= screen.maxY - height
        let rightInset = buttonScreen.map { screens[$0].maxX - buttonFrame.midX } ?? width / 2
        let centerX = isMenuBarClick ? mouseLocation.x : screen.maxX - rightInset
        let x = min(max(centerX - width / 2, screen.minX), screen.maxX - width)
        return MenuBarAnchor(screenIndex: target,
                             rect: CGRect(x: x, y: screen.maxY - height, width: width, height: height),
                             usesStatusButton: false)
    }
}
