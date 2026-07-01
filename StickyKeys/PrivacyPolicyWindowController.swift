import AppKit
import SwiftUI

@MainActor
/// Manages the application's Privacy Policy window.
final class PrivacyPolicyWindowController: NSWindowController, NSWindowDelegate {
    init() {
        let hostingController = NSHostingController(rootView: PrivacyPolicyView())
        let window = NSWindow(contentViewController: hostingController)

        window.title = "Privacy Policy"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 540, height: 430))
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Brings the existing Privacy Policy window to the foreground.
    func show() {
        guard let window else { return }
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}
