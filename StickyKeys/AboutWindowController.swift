import AppKit
import SwiftUI

@MainActor
/// Manages the application's About window.
final class AboutWindowController: NSWindowController, NSWindowDelegate {
    init() {
        let hostingController = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hostingController)

        window.title = "About StickyKeys"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 390))
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Brings the existing About window to the foreground.
    func show() {
        guard let window else { return }
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}
