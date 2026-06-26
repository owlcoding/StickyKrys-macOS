import Combine
import ServiceManagement

@MainActor
/// Udostępnia stan i zmianę rejestracji aplikacji jako elementu logowania macOS.
final class LaunchAtLoginManager: ObservableObject {
    /// Informuje, czy główna aplikacja jest obecnie zarejestrowana do startu przy logowaniu.
    @Published private(set) var isEnabled = false
    /// Opis ostatniego błędu rejestracji lub `nil`, jeśli ostatnia operacja się powiodła.
    @Published private(set) var lastError: String?

    /// Odczytuje aktualny stan z `SMAppService`.
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Rejestruje albo wyrejestrowuje aplikację z elementów logowania.
    /// - Parameter enabled: `true`, aby uruchamiać aplikację przy logowaniu.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}
