import Foundation

/// Delegate for the overlay panel — notifies when the panel loses focus.
protocol OverlayPanelDelegate: AnyObject {
    func overlayPanelDidResignKey()
}

/// Delegate for the overlay view controller — requests dismissal or paste.
protocol OverlayViewControllerDelegate: AnyObject {
    func overlayDidRequestDismiss()
    func overlayDidSelectItem()
}
