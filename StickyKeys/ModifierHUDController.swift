import AppKit
import Combine

@MainActor
/// Wyświetla nieaktywujący panel HUD z symbolem oczekującego modyfikatora.
final class ModifierHUDController {
    private let panel: NSPanel
    private let symbolLabel = NSTextField(labelWithString: "")
    private let lockIndicator = NSView()
    private var cancellables = Set<AnyCancellable>()

    /// Tworzy HUD i wiąże jego widoczność ze stanem modyfikatora.
    /// - Parameter modifierState: Obserwowany stan jednorazowego modyfikatora.
    init(modifierState: ModifierState) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 112, height: 112),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        configureContent()

        modifierState.$pending
            .combineLatest(modifierState.$locked)
            .sink { [weak self] pending, locked in
                self?.update(pending: pending, locked: locked)
            }
            .store(in: &cancellables)
    }

    private func configurePanel() {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.setAccessibilityRole(.group)
        panel.setAccessibilityLabel("Pending modifier")
    }

    private func configureContent() {
        let effectView = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 22
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor

        symbolLabel.translatesAutoresizingMaskIntoConstraints = false
        symbolLabel.font = .systemFont(ofSize: 58, weight: .semibold)
        symbolLabel.textColor = .labelColor
        symbolLabel.alignment = .center
        symbolLabel.maximumNumberOfLines = 1
        effectView.addSubview(symbolLabel)

        lockIndicator.translatesAutoresizingMaskIntoConstraints = false
        lockIndicator.wantsLayer = true
        lockIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
        lockIndicator.layer?.cornerRadius = 6
        lockIndicator.layer?.borderWidth = 1
        lockIndicator.layer?.borderColor = NSColor.white.withAlphaComponent(0.72).cgColor
        lockIndicator.isHidden = true
        effectView.addSubview(lockIndicator)

        NSLayoutConstraint.activate([
            symbolLabel.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
            symbolLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor, constant: -2),
            lockIndicator.widthAnchor.constraint(equalToConstant: 12),
            lockIndicator.heightAnchor.constraint(equalToConstant: 12),
            lockIndicator.leadingAnchor.constraint(equalTo: symbolLabel.trailingAnchor, constant: 2),
            lockIndicator.centerYAnchor.constraint(equalTo: symbolLabel.centerYAnchor, constant: -18),
        ])

        panel.contentView = effectView
    }

    private func update(pending: PendingModifier?, locked: PendingModifier?) {
        guard let modifier = locked ?? pending else {
            panel.orderOut(nil)
            return
        }

        symbolLabel.stringValue = modifier.symbol
        lockIndicator.isHidden = locked == nil
        panel.setAccessibilityValue(locked == nil ? modifier.displayName : "Locked \(modifier.displayName)")
        positionOnCurrentScreen()
        panel.orderFrontRegardless()
    }

    private func positionOnCurrentScreen() {
        // HUD trafia na ekran zawierający kursor, co odpowiada aktualnemu kontekstowi pracy.
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let margin: CGFloat = 24
        panel.setFrameOrigin(NSPoint(
            x: visibleFrame.maxX - panel.frame.width - margin,
            y: visibleFrame.maxY - panel.frame.height - margin
        ))
    }
}
