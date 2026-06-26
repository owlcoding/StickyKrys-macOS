import AppKit
import SwiftUI

@main
/// Punkt wejścia aplikacji menu-bar korzystającej z cyklu życia SwiftUI.
struct StickyKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Pusta scena ustawień utrzymuje cykl życia SwiftUI bez tworzenia głównego okna.
    var body: some Scene {
        // The visible menu is an AppKit NSStatusItem. Keeping a Settings scene gives
        // the SwiftUI app lifecycle a windowless scene without creating a main window.
        Settings { EmptyView() }
    }
}
