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
        case .stopped: "Input capture stopped"
        case .disabled: "Input capture disabled"
        case .needsAccessibility: "Input capture needs Accessibility permission"
        case .running: "Input capture active"
        case .failed: "Input capture could not start — check Input Monitoring"
        }
    }
}

@MainActor
/// Przechwytuje globalne zdarzenia wejścia i stosuje sticky modyfikator.
///
/// Shift, Option lub Command po wybranej stronie ustawia oczekujący modyfikator. Następne
/// naciśnięcie zwykłego klawisza otrzymuje odpowiednią flagę, po czym stan jest czyszczony.
/// Zdarzenia myszy dostają aktywną flagę bez zużywania oczekującego modyfikatora.
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
    private var triggerShiftIsDown = false
    private var triggerOptionIsDown = false
    private var triggerCommandIsDown = false
    private var modifiedKey: ModifiedKey?
    private var modifiedMouseButtons: [Int64: [PendingModifier]] = [:]
    private var lastShiftTapTime: TimeInterval?

    /// Tworzy menedżer korzystający ze wskazanych ustawień i współdzielonego stanu modyfikatora.
    /// - Parameters:
    ///   - settings: Ustawienia określające aktywne klawisze wyzwalające.
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
            | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.scrollWheel.rawValue)

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
        resetTrackedState()
        status = newStatus
    }

    /// Czyści śledzone stany fizycznych klawiszy bez zatrzymywania event tapu.
    func resetTrackedState() {
        triggerShiftIsDown = false
        triggerOptionIsDown = false
        triggerCommandIsDown = false
        modifiedKey = nil
        modifiedMouseButtons = [:]
        lastShiftTapTime = nil
    }

    /// Przetwarza pojedyncze zdarzenie przekazane przez callback Core Graphics.
    /// - Returns: Zdarzenie przekazywane dalej albo `nil`, gdy ma zostać stłumione.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if settings.mouseActionsEnabled, type.isMouseAction {
            return handleMouseAction(type: type, event: event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == settings.triggerSide.shiftKeyCode, settings.rightShiftEnabled {
            return handleTriggerShift(type: type, event: event)
        }

        if keyCode == settings.triggerSide.optionKeyCode, settings.rightOptionEnabled {
            return handleTriggerOption(type: type, event: event)
        }

        if keyCode == settings.triggerSide.commandKeyCode, settings.rightCommandEnabled {
            return handleTriggerCommand(type: type, event: event)
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

    private func handleMouseAction(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .scrollWheel {
            let modifiers = modifierState.activeModifiers
            if !modifiers.isEmpty {
                event.flags.insert(modifiers.eventFlags)
            }
            return Unmanaged.passUnretained(event)
        }

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let modifiers = modifierState.activeModifiers
            if !modifiers.isEmpty {
                event.flags.insert(modifiers.eventFlags)
                modifiedMouseButtons[buttonNumber] = modifiers
            }
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if let modifiers = modifiedMouseButtons[buttonNumber] {
                event.flags.insert(modifiers.eventFlags)
            }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if let modifiers = modifiedMouseButtons.removeValue(forKey: buttonNumber) {
                event.flags.insert(modifiers.eventFlags)
            }
        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleTriggerShift(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            if triggerShiftIsDown {
                triggerShiftIsDown = false
            } else {
                triggerShiftIsDown = true
                handleTriggerShiftPress()
            }
            return nil
        case .keyDown:
            guard !triggerShiftIsDown else { return nil }
            triggerShiftIsDown = true
            handleTriggerShiftPress()
            return nil
        case .keyUp:
            triggerShiftIsDown = false
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleTriggerShiftPress() {
        if modifierState.isLocked(.shift) {
            modifierState.unlock(.shift)
            lastShiftTapTime = nil
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let isQuickSecondTap = lastShiftTapTime.map {
            now - $0 <= Self.shiftLockDoubleTapInterval
        } ?? false

        if settings.rightShiftLockEnabled, modifierState.pending == .shift, isQuickSecondTap {
            modifierState.lock(.shift)
            lastShiftTapTime = nil
            return
        }

        modifierState.toggle(.shift)
        lastShiftTapTime = now
    }

    private func handleTriggerOption(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            // Modifier keys arrive primarily as flagsChanged. Tracking this particular
            // key's transitions avoids confusing the trigger Option with the other side.
            if triggerOptionIsDown {
                triggerOptionIsDown = false
            } else {
                triggerOptionIsDown = true
                modifierState.toggle(.option)
            }
            return nil
        case .keyDown:
            guard !triggerOptionIsDown else { return nil }
            triggerOptionIsDown = true
            modifierState.toggle(.option)
            return nil
        case .keyUp:
            triggerOptionIsDown = false
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleTriggerCommand(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            if triggerCommandIsDown {
                triggerCommandIsDown = false
            } else {
                triggerCommandIsDown = true
                modifierState.toggle(.command)
            }
            return nil
        case .keyDown:
            guard !triggerCommandIsDown else { return nil }
            triggerCommandIsDown = true
            modifierState.toggle(.command)
            return nil
        case .keyUp:
            triggerCommandIsDown = false
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

private extension TriggerKeySide {
    var shiftKeyCode: CGKeyCode {
        switch self {
        case .right: CGKeyCode(kVK_RightShift)
        case .left: CGKeyCode(kVK_Shift)
        }
    }

    var optionKeyCode: CGKeyCode {
        switch self {
        case .right: CGKeyCode(kVK_RightOption)
        case .left: CGKeyCode(kVK_Option)
        }
    }

    var commandKeyCode: CGKeyCode {
        switch self {
        case .right: CGKeyCode(kVK_RightCommand)
        case .left: CGKeyCode(kVK_Command)
        }
    }
}

private extension CGEventType {
    var isMouseAction: Bool {
        switch self {
        case .leftMouseDown,
             .leftMouseUp,
             .rightMouseDown,
             .rightMouseUp,
             .otherMouseDown,
             .otherMouseUp,
             .leftMouseDragged,
             .rightMouseDragged,
             .otherMouseDragged,
             .scrollWheel:
            true
        default:
            false
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
