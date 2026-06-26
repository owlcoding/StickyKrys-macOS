import AppKit
import SwiftUI

@MainActor
/// Zarządza pojedynczym oknem SwiftUI zawierającym opcje aplikacji.
final class OptionsWindowController: NSWindowController, NSWindowDelegate {
    /// Tworzy okno powiązane z ustawieniami, uruchamianiem przy logowaniu i uprawnieniami.
    init(
        settings: SettingsStore,
        launchAtLogin: LaunchAtLoginManager,
        permissions: PermissionManager
    ) {
        let rootView = OptionsView(
            settings: settings,
            launchAtLogin: launchAtLogin,
            permissions: permissions
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "StickyKeys Options"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 560, height: 620))
        window.minSize = NSSize(width: 560, height: 500)
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
