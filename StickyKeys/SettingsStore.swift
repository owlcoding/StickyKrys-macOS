import Combine
import Foundation

@MainActor
/// Przechowuje wybór klawiszy wyzwalających i synchronizuje go z `UserDefaults`.
final class SettingsStore: ObservableObject {
    private enum Key {
        static let rightShiftEnabled = "rightShiftEnabled"
        static let rightShiftLockEnabled = "rightShiftLockEnabled"
        static let legacyCapsLockEnabled = "capsLockEnabled"
        static let rightOptionEnabled = "rightOptionEnabled"
        static let rightCommandEnabled = "rightCommandEnabled"
    }

    /// Włącza użycie prawego Shift jako wyzwalacza jednorazowego modyfikatora.
    @Published var rightShiftEnabled: Bool {
        didSet { defaults.set(rightShiftEnabled, forKey: Key.rightShiftEnabled) }
    }

    /// Włącza blokadę Shift po szybkim dwukrotnym naciśnięciu prawego Shift.
    @Published var rightShiftLockEnabled: Bool {
        didSet { defaults.set(rightShiftLockEnabled, forKey: Key.rightShiftLockEnabled) }
    }

    /// Włącza użycie prawego Option jako wyzwalacza jednorazowego modyfikatora.
    @Published var rightOptionEnabled: Bool {
        didSet { defaults.set(rightOptionEnabled, forKey: Key.rightOptionEnabled) }
    }

    /// Włącza użycie prawego Command jako wyzwalacza jednorazowego modyfikatora.
    @Published var rightCommandEnabled: Bool {
        didSet { defaults.set(rightCommandEnabled, forKey: Key.rightCommandEnabled) }
    }

    /// Informuje, czy co najmniej jeden wyzwalacz wymaga aktywnego event tapu.
    var capturesAnyTrigger: Bool {
        rightShiftEnabled || rightOptionEnabled || rightCommandEnabled
    }

    private let defaults: UserDefaults

    /// Tworzy magazyn i wczytuje zapisane ustawienia.
    /// - Parameter defaults: Magazyn używany do trwałego zapisu; domyślnie standardowy.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedRightShift = defaults.object(forKey: Key.rightShiftEnabled) as? Bool
        let legacyCapsLock = defaults.object(forKey: Key.legacyCapsLockEnabled) as? Bool

        // Rejestracja wartości domyślnych zachowuje zapis użytkownika, jeśli już istnieje.
        defaults.register(defaults: [
            Key.rightShiftLockEnabled: true,
            Key.rightOptionEnabled: true,
            Key.rightCommandEnabled: true,
        ])
        // Dawne ustawienie Caps Lock jest jednorazowym źródłem wartości dla Right Shift.
        rightShiftEnabled = storedRightShift ?? legacyCapsLock ?? true
        rightShiftLockEnabled = defaults.bool(forKey: Key.rightShiftLockEnabled)
        rightOptionEnabled = defaults.bool(forKey: Key.rightOptionEnabled)
        rightCommandEnabled = defaults.bool(forKey: Key.rightCommandEnabled)
    }
}
