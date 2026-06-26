import Carbon.HIToolbox
import Combine
import CoreGraphics
import Foundation

/// Stan globalnego przechwytywania zdarzeń klawiatury.
enum EventTapStatus: Equatable {
    case stopped
    case disabled
    case needsAccessibility
    case running
    case failed

    /// Tekst prezentowany użytkownikowi w menu aplikacji.
    var displayText: String {
        switch self {
        case .stopped: "Keyboard capture stopped"
        case .disabled: "Keyboard capture disabled"
        case .needsAccessibility: "Keyboard capture needs Accessibility permission"
        case .running: "Keyboard capture active"
        case .failed: "Keyboard capture could not start — check Input Monitoring"
        }
    }
}

@MainActor
/// Przechwytuje globalne zdarzenia klawiatury i stosuje jednorazowy modyfikator.
///
/// Prawy Shift, Option lub Command ustawia oczekujący modyfikator. Następne
/// naciśnięcie zwykłego klawisza otrzymuje odpowiednią flagę, po czym stan jest czyszczony.
final class EventTapManager: ObservableObject {
    /// Aktualny stan event tapu widoczny dla interfejsu użytkownika.
    @Published private(set) var status: EventTapStatus = .stopped

    private struct ModifiedKey {
        let keyCode: CGKeyCode
        let modifiers: [PendingModifier]
    }

    private static let shiftLockDoubleTapInterval: TimeInterval = 0.45

    private let settings: SettingsStore
    private let modifierState: ModifierState

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var rightShiftIsDown = false
    private var rightOptionIsDown = false
    private var rightCommandIsDown = false
    private var modifiedKey: ModifiedKey?
    private var lastRightShiftTapTime: TimeInterval?

    /// Tworzy menedżer korzystający ze wskazanych ustawień i współdzielonego stanu modyfikatora.
    /// - Parameters:
    ///   - settings: Ustawienia określające aktywne prawe klawisze wyzwalające.
    ///   - modifierState: Stan jednorazowego modyfikatora aktualizowany przez zdarzenia.
    init(settings: SettingsStore, modifierState: ModifierState) {
        self.settings = settings
        self.modifierState = modifierState
    }

    /// Tworzy i uruchamia globalny event tap albo ponownie włącza istniejący.
    ///
    /// Gdy system odmówi utworzenia tapu, ustawia stan `.failed`.
    func start() {
        guard tap == nil else {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            status = .running
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            status = .failed
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        tap = eventTap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        status = .running
    }

    /// Zatrzymuje event tap, usuwa źródło run loop i czyści śledzone naciśnięcia.
    /// - Parameter newStatus: Stan raportowany po zatrzymaniu.
    func stop(status newStatus: EventTapStatus = .stopped) {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tap = nil
        rightShiftIsDown = false
        rightOptionIsDown = false
        rightCommandIsDown = false
        modifiedKey = nil
        lastRightShiftTapTime = nil
        status = newStatus
    }

    /// Przetwarza pojedyncze zdarzenie przekazane przez callback Core Graphics.
    /// - Returns: Zdarzenie przekazywane dalej albo `nil`, gdy ma zostać stłumione.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == CGKeyCode(kVK_RightShift), settings.rightShiftEnabled {
            return handleRightShift(type: type, event: event)
        }

        if keyCode == CGKeyCode(kVK_RightOption), settings.rightOptionEnabled {
            return handleRightOption(type: type, event: event)
        }

        if keyCode == CGKeyCode(kVK_RightCommand), settings.rightCommandEnabled {
            return handleRightCommand(type: type, event: event)
        }

        if keyCode == CGKeyCode(kVK_Escape), type == .keyDown, modifierState.hasActiveModifier {
            modifierState.cancel()
            // Escape still reaches the active application; only the active modifier state is cancelled.
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            if let modifiedKey, modifiedKey.keyCode == keyCode {
                event.flags.insert(modifiedKey.modifiers.eventFlags)
                return Unmanaged.passUnretained(event)
            }

            let modifiers = modifierState.consumeForKey()
            if !modifiers.isEmpty {
                event.flags.insert(modifiers.eventFlags)
                modifiedKey = ModifiedKey(keyCode: keyCode, modifiers: modifiers)
            }
        } else if type == .keyUp, let modifiedKey, modifiedKey.keyCode == keyCode {
            // Carry the synthetic modifier through keyUp so applications see a balanced
            // modified keystroke. Auto-repeat keyDown events are handled by the branch above.
            event.flags.insert(modifiedKey.modifiers.eventFlags)
            self.modifiedKey = nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleRightShift(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            if rightShiftIsDown {
                rightShiftIsDown = false
            } else {
                rightShiftIsDown = true
                handleRightShiftPress()
            }
            return nil
        case .keyDown:
            guard !rightShiftIsDown else { return nil }
            rightShiftIsDown = true
            handleRightShiftPress()
            return nil
        case .keyUp:
            rightShiftIsDown = false
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleRightShiftPress() {
        if modifierState.isLocked(.shift) {
            modifierState.unlock(.shift)
            lastRightShiftTapTime = nil
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let isQuickSecondTap = lastRightShiftTapTime.map {
            now - $0 <= Self.shiftLockDoubleTapInterval
        } ?? false

        if settings.rightShiftLockEnabled, modifierState.pending == .shift, isQuickSecondTap {
            modifierState.lock(.shift)
            lastRightShiftTapTime = nil
            return
        }

        modifierState.toggle(.shift)
        lastRightShiftTapTime = now
    }

    private func handleRightOption(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            // Modifier keys arrive primarily as flagsChanged. Tracking this particular
            // key's transitions avoids confusing Right Option with a held Left Option.
            if rightOptionIsDown {
                rightOptionIsDown = false
            } else {
                rightOptionIsDown = true
                modifierState.toggle(.option)
            }
            return nil
        case .keyDown:
            guard !rightOptionIsDown else { return nil }
            rightOptionIsDown = true
            modifierState.toggle(.option)
            return nil
        case .keyUp:
            rightOptionIsDown = false
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleRightCommand(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            if rightCommandIsDown {
                rightCommandIsDown = false
            } else {
                rightCommandIsDown = true
                modifierState.toggle(.command)
            }
            return nil
        case .keyDown:
            guard !rightCommandIsDown else { return nil }
            rightCommandIsDown = true
            modifierState.toggle(.command)
            return nil
        case .keyUp:
            rightCommandIsDown = false
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

private extension Array where Element == PendingModifier {
    var eventFlags: CGEventFlags {
        reduce([]) { flags, modifier in
            flags.union(modifier.eventFlag)
        }
    }
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    // `userInfo` wskazuje na żyjącego menedżera; event tap nie przejmuje jego własności.
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
    return MainActor.assumeIsolated {
        manager.handle(type: type, event: event)
    }
}
