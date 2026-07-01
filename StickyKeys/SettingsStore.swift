import Combine
import Foundation

/// Strona klawiatury używana jako źródło sticky modyfikatorów.
enum TriggerKeySide: String, CaseIterable, Identifiable, Equatable {
    case right
    case left

    var id: String { rawValue }

    /// Krótka nazwa używana w selektorze opcji.
    var displayName: String {
        switch self {
        case .right: "Right Side"
        case .left: "Left Side"
        }
    }

    /// Przymiotnik używany w etykietach ustawień.
    var keyLabelPrefix: String {
        switch self {
        case .right: "Right"
        case .left: "Left"
        }
    }
}

@MainActor
/// Przechowuje wybór klawiszy wyzwalających i synchronizuje go z `UserDefaults`.
final class SettingsStore: ObservableObject {
    private enum Key {
        static let triggerSide = "triggerSide"
        static let rightShiftEnabled = "rightShiftEnabled"
        static let rightShiftLockEnabled = "rightShiftLockEnabled"
        static let legacyCapsLockEnabled = "capsLockEnabled"
        static let rightOptionEnabled = "rightOptionEnabled"
        static let rightCommandEnabled = "rightCommandEnabled"
        static let mouseActionsEnabled = "mouseActionsEnabled"
        static let onboardingCompleted = "onboardingCompleted"
    }

    /// Strona klawiatury, z której klawisze modyfikujące są przejmowane jako sticky.
    @Published var triggerSide: TriggerKeySide {
        didSet { defaults.set(triggerSide.rawValue, forKey: Key.triggerSide) }
    }

    /// Włącza użycie wybranego Shift jako wyzwalacza jednorazowego modyfikatora.
    @Published var rightShiftEnabled: Bool {
        didSet { defaults.set(rightShiftEnabled, forKey: Key.rightShiftEnabled) }
    }

    /// Włącza blokadę Shift po szybkim dwukrotnym naciśnięciu wybranego Shift.
    @Published var rightShiftLockEnabled: Bool {
        didSet { defaults.set(rightShiftLockEnabled, forKey: Key.rightShiftLockEnabled) }
    }

    /// Włącza użycie wybranego Option jako wyzwalacza jednorazowego modyfikatora.
    @Published var rightOptionEnabled: Bool {
        didSet { defaults.set(rightOptionEnabled, forKey: Key.rightOptionEnabled) }
    }

    /// Włącza użycie wybranego Command jako wyzwalacza jednorazowego modyfikatora.
    @Published var rightCommandEnabled: Bool {
        didSet { defaults.set(rightCommandEnabled, forKey: Key.rightCommandEnabled) }
    }

    /// Włącza stosowanie oczekującego modyfikatora do kliknięć, przeciągania i przewijania.
    @Published var mouseActionsEnabled: Bool {
        didSet { defaults.set(mouseActionsEnabled, forKey: Key.mouseActionsEnabled) }
    }

    /// Informuje, czy co najmniej jeden wyzwalacz wymaga aktywnego event tapu.
    var capturesAnyTrigger: Bool {
        rightShiftEnabled || rightOptionEnabled || rightCommandEnabled
    }

    /// Informuje, czy użytkownik zakończył pierwszy onboarding.
    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Key.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
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
            Key.triggerSide: TriggerKeySide.right.rawValue,
            Key.rightShiftLockEnabled: true,
            Key.rightOptionEnabled: true,
            Key.rightCommandEnabled: true,
            Key.mouseActionsEnabled: false,
        ])
        // Dawne ustawienie Caps Lock jest jednorazowym źródłem wartości dla Shift.
        let storedTriggerSide = defaults.string(forKey: Key.triggerSide)
            .flatMap(TriggerKeySide.init(rawValue:))
        rightShiftEnabled = storedRightShift ?? legacyCapsLock ?? true
        rightShiftLockEnabled = defaults.bool(forKey: Key.rightShiftLockEnabled)
        rightOptionEnabled = defaults.bool(forKey: Key.rightOptionEnabled)
        rightCommandEnabled = defaults.bool(forKey: Key.rightCommandEnabled)
        mouseActionsEnabled = defaults.bool(forKey: Key.mouseActionsEnabled)
        triggerSide = storedTriggerSide ?? .right
    }
}
