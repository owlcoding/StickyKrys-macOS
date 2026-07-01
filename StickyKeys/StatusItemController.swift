import AppKit
import Combine

@MainActor
/// Buduje element paska menu i przekazuje akcje użytkownika do `AppController`.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let controller: AppController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()
    private var settingsStore: SettingsStore

    /// Tworzy element paska stanu powiązany z głównym kontrolerem aplikacji.
    init(controller: AppController, settingStore: SettingsStore) {
        self.controller = controller
        self.settingsStore = settingStore
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        updateStatusItem()

        controller.modifierState.$pending
            .combineLatest(controller.modifierState.$locked)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
    }

    /// Odświeża uprawnienia i przebudowuje menu bezpośrednio przed jego pokazaniem.
    func menuWillOpen(_ menu: NSMenu) {
        controller.refreshPermissionStatus()
        rebuildMenu()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
//        button.image = NSImage.icon1
        button.image = NSImage(
            systemSymbolName: settingsStore.triggerSide == .right ? "keyboard.onehanded.right" : "keyboard.onehanded.left",
            accessibilityDescription: "StickyKeys"
        )
        button.title = ""
        button.toolTip  = "StickyKeys — \(controller.modifierState.statusText)"
    }

    
    private func rebuildMenu() {
        menu.removeAllItems()

        addDisabledItem(statusText)
        addDisabledItem(controller.eventTap.status.displayText)
        menu.addItem(.separator())

        let cancel = addAction("Cancel Active Modifier", action: #selector(cancelActiveModifier))
        cancel.isEnabled = controller.modifierState.hasActiveModifier

        menu.addItem(.separator())

        addAction("Onboarding…", action: #selector(openOnboarding))
        addAction("Options…", action: #selector(openOptions))
        addAction("About StickyKeys…", action: #selector(openAbout))

        if controller.eventTap.status == .failed {
            addAction("Retry Keyboard Capture", action: #selector(retryKeyboardCapture))
        }

        menu.addItem(.separator())
        addAction("Quit StickyKeys", action: #selector(quit), keyEquivalent: "q")
    }

    @discardableResult
    private func addAction(
        _ title: String,
        action: Selector,
        state: Bool? = nil,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if let state {
            item.state = state ? .on : .off
        }
        menu.addItem(item)
        return item
    }

    private func addDisabledItem(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private var statusText: String {
        if controller.modifierState.hasActiveModifier {
            return controller.modifierState.statusText
        }
        return controller.settings.capturesAnyTrigger ? "Enabled" : "Disabled"
    }

    @objc private func cancelActiveModifier() {
        controller.modifierState.cancel()
    }

    @objc private func openOptions() {
        controller.showOptions()
    }

    @objc private func openOnboarding() {
        controller.showOnboarding()
    }

    @objc private func openAbout() {
        controller.showAbout()
    }

    @objc private func retryKeyboardCapture() {
        controller.permissions.refresh()
        controller.eventTap.start()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
