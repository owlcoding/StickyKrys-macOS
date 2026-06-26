import Combine
import Foundation

@MainActor
/// Koordynuje ustawienia aplikacji, uprawnienia systemowe i przechwytywanie klawiatury.
final class AppController: NSObject {
    /// Współdzielona instancja używana przez cykl życia aplikacji i interfejs paska menu.
    static let shared = AppController()

    /// Ustawienia wyzwalaczy zapisywane w `UserDefaults`.
    let settings = SettingsStore()
    /// Bieżący modyfikator oczekujący na użycie z następnym klawiszem.
    let modifierState = ModifierState()
    /// Stan wymaganych uprawnień prywatności macOS.
    let permissions = PermissionManager()
    /// Zarządza uruchamianiem aplikacji podczas logowania użytkownika.
    let launchAtLogin = LaunchAtLoginManager()

    private(set) lazy var eventTap = EventTapManager(
        settings: settings,
        modifierState: modifierState
    )
    private lazy var permissionsWindow = PermissionsWindowController(permissions: permissions)
    private lazy var aboutWindow = AboutWindowController()
    private var cancellables = Set<AnyCancellable>()
    private var permissionTimer: Timer?
    private var hasStarted = false

    private override init() {
        super.init()
        settings.$rightShiftEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled, self.modifierState.pending == .shift || self.modifierState.locked == .shift {
                    self.modifierState.cancel()
                }
                self.updateEventTap()
            }
            .store(in: &cancellables)

        settings.$rightShiftLockEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled, self.modifierState.locked == .shift {
                    self.modifierState.unlock(.shift)
                }
            }
            .store(in: &cancellables)

        settings.$rightOptionEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled, self.modifierState.pending == .option {
                    self.modifierState.cancel()
                }
                self.updateEventTap()
            }
            .store(in: &cancellables)

        settings.$rightCommandEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled, self.modifierState.pending == .command {
                    self.modifierState.cancel()
                }
                self.updateEventTap()
            }
            .store(in: &cancellables)
    }

    /// Uruchamia kontroler i okresowe odświeżanie uprawnień.
    ///
    /// Kolejne wywołania nie tworzą dodatkowych timerów ani event tapów.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        permissions.refresh()
        launchAtLogin.refresh()
        updateEventTap()

        if !permissions.accessibilityGranted {
            Task { @MainActor [weak self] in
                self?.showPermissions()
            }
        }

        permissionTimer = Timer.scheduledTimer(
            timeInterval: 2,
            target: self,
            selector: #selector(refreshPermissions),
            userInfo: nil,
            repeats: true
        )
    }

    /// Zatrzymuje okresowe sprawdzanie uprawnień i przechwytywanie klawiatury.
    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        eventTap.stop()
    }

    /// Odświeża uprawnienia i wyświetla okno z instrukcjami dostępu.
    func showPermissions() {
        permissions.refresh()
        permissionsWindow.show()
    }

    /// Displays information about the application and its authors.
    func showAbout() {
        aboutWindow.show()
    }

    /// Natychmiast odświeża stan uprawnień oraz zależny od niego event tap.
    func refreshPermissionStatus() {
        refreshPermissions()
    }

    private func updateEventTap() {
        guard settings.capturesAnyTrigger else {
            eventTap.stop(status: .disabled)
            modifierState.cancel()
            return
        }

        // An active (suppressing) event tap fundamentally requires Accessibility.
        // On some macOS versions Accessibility also grants keyboard listening; on
        // others Input Monitoring is additionally required. Attempt creation as soon
        // as Accessibility is present and report a failed tap explicitly in the menu.
        if permissions.accessibilityGranted {
            eventTap.start()
        } else {
            eventTap.stop(status: .needsAccessibility)
        }
    }

    @objc private func refreshPermissions() {
        let previousAccessibility = permissions.accessibilityGranted
        let previousInputMonitoring = permissions.inputMonitoringGranted
        permissions.refresh()

        if previousAccessibility != permissions.accessibilityGranted
            || previousInputMonitoring != permissions.inputMonitoringGranted {
            updateEventTap()
        }
    }
}
