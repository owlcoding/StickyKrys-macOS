import AppKit
import SwiftUI

@MainActor
/// Zarządza pojedynczym oknem SwiftUI zawierającym instrukcje nadania uprawnień.
final class PermissionsWindowController: NSWindowController, NSWindowDelegate {
    /// Tworzy okno powiązane z przekazanym menedżerem uprawnień.
    init(permissions: PermissionManager) {
        let rootView = PermissionsView(permissions: permissions)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "StickyKeys Permissions"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 330))
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Pokazuje okno na pierwszym planie i aktywuje aplikację.
    func show() {
        guard let window else { return }
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}
