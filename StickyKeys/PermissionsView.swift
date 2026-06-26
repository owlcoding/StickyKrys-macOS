import SwiftUI

/// Widok prezentujący stan uprawnień oraz akcje prowadzące do ich nadania.
struct PermissionsView: View {
    /// Obserwowany menedżer uprawnień systemowych.
    @ObservedObject var permissions: PermissionManager

    /// Zawartość okna uprawnień.
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Keyboard Permissions")
                .font(.title2.bold())

            Text("StickyKeys needs permission to observe and suppress global keyboard events. Enable the app in both privacy lists, then return here. The status refreshes automatically.")
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

            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 330)
        .onAppear { permissions.refresh() }
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
