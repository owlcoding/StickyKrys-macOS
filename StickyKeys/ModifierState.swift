import Combine
import CoreGraphics
import Foundation

/// Modyfikator, który może zostać zastosowany do następnego naciśnięcia klawisza.
enum PendingModifier: String, Sendable {
    case shift
    case option
    case command

    /// Flaga Core Graphics odpowiadająca modyfikatorowi.
    var eventFlag: CGEventFlags {
        switch self {
        case .shift: .maskShift
        case .option: .maskAlternate
        case .command: .maskCommand
        }
    }

    /// Czytelna nazwa używana w interfejsie i dostępności.
    var displayName: String {
        switch self {
        case .shift: "Shift"
        case .option: "Option"
        case .command: "Command"
        }
    }

    /// Typograficzny symbol klawisza modyfikującego.
    var symbol: String {
        switch self {
        case .shift: "⇧"
        case .option: "⌥"
        case .command: "⌘"
        }
    }
}

@MainActor
/// Przechowuje jednorazowy i zablokowany modyfikator stosowany do klawiszy i myszy.
final class ModifierState: ObservableObject {
    /// Aktualnie oczekujący modyfikator lub `nil`, gdy aplikacja jest gotowa.
    @Published private(set) var pending: PendingModifier?
    /// Modyfikator stosowany do wszystkich kolejnych klawiszy.
    @Published private(set) var locked: PendingModifier?

    /// Czytelny opis stanu używany w menu i podpowiedzi paska menu.
    var statusText: String {
        if let locked {
            return "Locked \(locked.displayName)"
        }
        return pending.map { "Pending \($0.displayName)" } ?? "Ready"
    }

    /// Tytuł paska menu odzwierciedlający oczekujący modyfikator.
    var menuBarTitle: String {
        locked?.symbol ?? pending?.symbol ?? "StickyKeys"
    }

    /// Nazwa symbolu SF Symbols odpowiadającego bieżącemu stanowi.
    var menuBarSymbol: String {
        locked == nil && pending == nil ? "keyboard.badge.ellipsis" : "keyboard.badge.clock"
    }

    /// Informuje, czy istnieje modyfikator do anulowania lub zastosowania.
    var hasActiveModifier: Bool {
        pending != nil || locked != nil
    }

    /// Aktywne modyfikatory bez czyszczenia stanu jednorazowego.
    var activeModifiers: [PendingModifier] {
        var modifiers: [PendingModifier] = []
        if let locked {
            modifiers.append(locked)
        }
        if let pending, pending != locked {
            modifiers.append(pending)
        }
        return modifiers
    }

    /// Ustawia modyfikator lub anuluje go, jeśli ten sam wyzwalacz naciśnięto ponownie.
    /// - Parameter modifier: Modyfikator powiązany z naciśniętym wyzwalaczem.
    /// - Returns: `true`, gdy operacja anulowała już oczekującą wartość.
    @discardableResult
    func toggle(_ modifier: PendingModifier) -> Bool {
        if pending == modifier {
            pending = nil
            return true
        }
        pending = modifier
        return false
    }

    /// Włącza modyfikator stosowany do wszystkich kolejnych klawiszy.
    /// - Parameter modifier: Modyfikator, który ma pozostać aktywny.
    func lock(_ modifier: PendingModifier) {
        pending = nil
        locked = modifier
    }

    /// Wyłącza zablokowany modyfikator, jeśli odpowiada wskazanemu klawiszowi.
    /// - Parameter modifier: Modyfikator do odblokowania.
    func unlock(_ modifier: PendingModifier) {
        if locked == modifier {
            locked = nil
        }
    }

    /// Sprawdza, czy wskazany modyfikator jest aktualnie zablokowany.
    /// - Parameter modifier: Modyfikator do sprawdzenia.
    /// - Returns: `true`, gdy modyfikator pozostaje aktywny dla kolejnych klawiszy.
    func isLocked(_ modifier: PendingModifier) -> Bool {
        locked == modifier
    }

    /// Pobiera aktywne modyfikatory i atomowo czyści wyłącznie stan jednorazowy.
    /// - Returns: Modyfikatory do zastosowania do najbliższego klawisza.
    func consumeForKey() -> [PendingModifier] {
        defer { pending = nil }
        return activeModifiers
    }

    /// Usuwa oczekujący modyfikator bez stosowania go do zdarzenia.
    func cancel() {
        pending = nil
        locked = nil
    }
}
