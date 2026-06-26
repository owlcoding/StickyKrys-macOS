import AppKit
import ApplicationServices
import Combine
import CoreGraphics

@MainActor
/// Odczytuje i inicjuje uprawnienia prywatności wymagane przez globalny event tap.
final class PermissionManager: ObservableObject {
    /// Informuje, czy aplikacja znajduje się na liście Dostępność.
    @Published private(set) var accessibilityGranted = false
    /// Informuje, czy aplikacja ma dostęp do Monitorowania wprowadzania.
    @Published private(set) var inputMonitoringGranted = false

    /// `true`, gdy przyznano oba uprawnienia prezentowane jako wymagane.
    var hasRequiredPermissions: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    /// Ponownie odczytuje oba stany uprawnień z systemu.
    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    /// Wyświetla systemowy monit o dostęp do funkcji Dostępność.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    /// Prosi o Monitorowanie wprowadzania i otwiera Ustawienia, gdy dostęp nie został przyznany.
    func requestInputMonitoring() {
        inputMonitoringGranted = CGRequestListenEventAccess()
        if !inputMonitoringGranted {
            openInputMonitoringSettings()
        }
    }

    /// Otwiera sekcję Dostępność w systemowych ustawieniach prywatności.
    func openAccessibilitySettings() {
        openPrivacyPane(anchor: "Privacy_Accessibility")
    }

    /// Otwiera sekcję Monitorowanie wprowadzania w ustawieniach prywatności.
    func openInputMonitoringSettings() {
        openPrivacyPane(anchor: "Privacy_ListenEvent")
    }

    private func openPrivacyPane(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
