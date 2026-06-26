import AppKit
import Combine

@MainActor
/// Wyświetla nieaktywujący panel HUD z symbolami aktywnych modyfikatorów.
final class ModifierHUDController {
    private static let singleModifierSize = NSSize(width: 112, height: 112)
    private static let combinedModifierSize = NSSize(width: 148, height: 112)

    private let panel: NSPanel
    private let stackView = NSStackView()
    private var cancellables = Set<AnyCancellable>()

    /// Tworzy HUD i wiąże jego widoczność ze stanem modyfikatora.
    /// - Parameter modifierState: Obserwowany stan jednorazowego modyfikatora.
    init(modifierState: ModifierState) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.singleModifierSize),
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

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fill
        stackView.spacing = 8
        effectView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: effectView.centerYAnchor, constant: -2),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: effectView.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: effectView.trailingAnchor, constant: -14),
        ])

        panel.contentView = effectView
    }

    private func update(pending: PendingModifier?, locked: PendingModifier?) {
        let modifiers = displayedModifiers(pending: pending, locked: locked)
        guard !modifiers.isEmpty else {
            panel.orderOut(nil)
            return
        }

        updateSymbols(modifiers)
        updatePanelSize(for: modifiers)
        panel.setAccessibilityValue(accessibilityValue(for: modifiers))
        positionOnCurrentScreen()
        panel.orderFrontRegardless()
    }

    private func displayedModifiers(
        pending: PendingModifier?,
        locked: PendingModifier?
    ) -> [(modifier: PendingModifier, isLocked: Bool)] {
        var modifiers: [(PendingModifier, Bool)] = []
        if let locked {
            modifiers.append((locked, true))
        }
        if let pending, pending != locked {
            modifiers.append((pending, false))
        }
        return modifiers
    }

    private func updateSymbols(_ modifiers: [(modifier: PendingModifier, isLocked: Bool)]) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let fontSize: CGFloat = modifiers.count > 1 ? 48 : 58
        for modifier in modifiers {
            stackView.addArrangedSubview(symbolView(
                for: modifier.modifier,
                isLocked: modifier.isLocked,
                fontSize: fontSize
            ))
        }
    }

    private func updatePanelSize(for modifiers: [(modifier: PendingModifier, isLocked: Bool)]) {
        let size = modifiers.count > 1 ? Self.combinedModifierSize : Self.singleModifierSize
        if panel.contentView?.frame.size != size {
            panel.setContentSize(size)
        }
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    private func symbolView(
        for modifier: PendingModifier,
        isLocked: Bool,
        fontSize: CGFloat
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let symbolLabel = NSTextField(labelWithString: modifier.symbol)
        symbolLabel.translatesAutoresizingMaskIntoConstraints = false
        symbolLabel.font = .systemFont(ofSize: fontSize, weight: .semibold)
        symbolLabel.textColor = .labelColor
        symbolLabel.alignment = .center
        symbolLabel.maximumNumberOfLines = 1
        container.addSubview(symbolLabel)

        var constraints: [NSLayoutConstraint] = [
            symbolLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            symbolLabel.topAnchor.constraint(equalTo: container.topAnchor),
            symbolLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ]

        if isLocked {
            let lockIndicator = NSView()
            lockIndicator.translatesAutoresizingMaskIntoConstraints = false
            lockIndicator.wantsLayer = true
            lockIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
            lockIndicator.layer?.cornerRadius = 5
            lockIndicator.layer?.borderWidth = 1
            lockIndicator.layer?.borderColor = NSColor.white.withAlphaComponent(0.72).cgColor
            container.addSubview(lockIndicator)

            constraints.append(contentsOf: [
                symbolLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
                lockIndicator.widthAnchor.constraint(equalToConstant: 10),
                lockIndicator.heightAnchor.constraint(equalToConstant: 10),
                lockIndicator.leadingAnchor.constraint(equalTo: symbolLabel.trailingAnchor, constant: -2),
                lockIndicator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                lockIndicator.centerYAnchor.constraint(equalTo: symbolLabel.centerYAnchor, constant: -16),
            ])
        } else {
            constraints.append(symbolLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor))
        }

        NSLayoutConstraint.activate(constraints)
        return container
    }

    private func accessibilityValue(
        for modifiers: [(modifier: PendingModifier, isLocked: Bool)]
    ) -> String {
        modifiers.map { item in
            item.isLocked ? "Locked \(item.modifier.displayName)" : item.modifier.displayName
        }.joined(separator: " and ")
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
