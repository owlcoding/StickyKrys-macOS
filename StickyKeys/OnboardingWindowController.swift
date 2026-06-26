import AppKit
import SwiftUI

@MainActor
/// Zarządza oknem pierwszorazowego przewodnika po aplikacji.
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let settings: SettingsStore

    init(
        settings: SettingsStore,
        modifierState: ModifierState
    ) {
        self.settings = settings

        let window = NSWindow()
        let rootView = OnboardingView(
            settings: settings,
            modifierState: modifierState,
            finish: {
                settings.onboardingCompleted = true
                window.close()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        window.contentViewController = hostingController

        window.title = "Welcome to StickyKeys"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 620, height: 650))
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Pokazuje przewodnik na pierwszym planie.
    func show() {
        guard let window else { return }
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        settings.onboardingCompleted = true
    }
}
