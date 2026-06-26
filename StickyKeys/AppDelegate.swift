import AppKit

@MainActor
/// Łączy cykl życia `NSApplication` z kontrolerami aplikacji działającej w pasku menu.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var modifierHUDController: ModifierHUDController?

    /// Konfiguruje aplikację jako akcesorium i uruchamia jej kontrolery interfejsu.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement hides the Dock icon; this is also set explicitly to avoid a
        // transient Dock icon when running an unsigned Debug build from Xcode.
        NSApp.setActivationPolicy(.accessory)
        AppController.shared.start()
        statusItemController = StatusItemController(controller: AppController.shared)
        modifierHUDController = ModifierHUDController(
            modifierState: AppController.shared.modifierState
        )
    }

    /// Zwalnia kontrolery oraz zatrzymuje przechwytywanie zdarzeń przed zakończeniem procesu.
    func applicationWillTerminate(_ notification: Notification) {
        AppController.shared.stop()
        modifierHUDController = nil
        statusItemController = nil
    }
}
