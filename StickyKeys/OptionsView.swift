import SwiftUI

/// Widok prezentujący ustawienia aplikacji, uruchamianie przy logowaniu i uprawnienia.
struct OptionsView: View {
    /// Ustawienia klawiszy wyzwalających.
    @ObservedObject var settings: SettingsStore
    /// Menedżer uruchamiania aplikacji przy logowaniu.
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    /// Menedżer uprawnień systemowych.
    @ObservedObject var permissions: PermissionManager
    /// Otwiera politykę prywatności aplikacji.
    let showPrivacyPolicy: () -> Void

    /// Zawartość okna opcji.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Keyboard Triggers") {
                    HStack(spacing: 14) {
                        Text("Trigger side")
                            .frame(width: 104, alignment: .leading)

                        Picker("Trigger side", selection: $settings.triggerSide) {
                            ForEach(TriggerKeySide.allCases) { side in
                                Text(side.displayName).tag(side)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }

                    Divider()

                    Toggle("\(settings.triggerSide.keyLabelPrefix) Shift enables one-shot Shift", isOn: $settings.rightShiftEnabled)
                    Toggle("Double \(settings.triggerSide.keyLabelPrefix) Shift enables Shift Lock", isOn: $settings.rightShiftLockEnabled)
                        .disabled(!settings.rightShiftEnabled)
                    Toggle("\(settings.triggerSide.keyLabelPrefix) Option enables one-shot Option", isOn: $settings.rightOptionEnabled)
                    Toggle("\(settings.triggerSide.keyLabelPrefix) Command enables one-shot Command", isOn: $settings.rightCommandEnabled)
                }

                section("Mouse Actions") {
                    Toggle("Enable modifiers for mouse click and scrolls", isOn: $settings.mouseActionsEnabled)
                }

                section("App") {
                    Toggle(
                        "Launch at Login",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )
                    )

                    if let lastError = launchAtLogin.lastError {
                        Label(lastError, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }

                    Button("Privacy Policy", action: showPrivacyPolicy)
                }

                section("Permissions") {
                    Text("StickyKeys needs permission to observe and suppress global keyboard and mouse events.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    permissionRow(
                        title: "Accessibility",
                        granted: permissions.accessibilityGranted,
                        request: permissions.requestAccessibility,
                        openSettings: permissions.openAccessibilitySettings
                    )

                    permissionRow(
                        title: "Input Monitoring",
                        granted: permissions.inputMonitoringGranted,
                        request: permissions.requestInputMonitoring,
                        openSettings: permissions.openInputMonitoringSettings
                    )

                    Text("If StickyKeys is already listed but does not work after an update, remove it from the list, add it again, and restart the app.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
        }
        .frame(width: 560)
        .frame(minHeight: 560)
        .onAppear {
            permissions.refresh()
            launchAtLogin.refresh()
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        request: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(title)
            Spacer()
            Text(granted ? "Granted" : "Required")
                .foregroundStyle(.secondary)
            if !granted {
                Button("Request", action: request)
                Button("Open Settings", action: openSettings)
            }
        }
    }
}
