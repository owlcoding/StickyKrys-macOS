import SwiftUI

/// Presents StickyKeys privacy commitments in-app.
struct PrivacyPolicyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Privacy Policy")
                    .font(.title.bold())
                Text("StickyKeys is privacy first because I care.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                privacyRow(
                    title: "No Network Use",
                    body: "StickyKeys does not connect to the internet and does not send anything anywhere."
                )

                privacyRow(
                    title: "No Logging",
                    body: "StickyKeys does not log keystrokes, mouse actions, shortcuts, typed text, app usage, or modifier activity."
                )

                privacyRow(
                    title: "No Analytics",
                    body: "StickyKeys includes no analytics, telemetry, tracking, crash reporting, ads, or third-party SDKs."
                )

                privacyRow(
                    title: "Local Only",
                    body: "Accessibility and Input Monitoring permissions are used only to turn selected modifier keys into sticky modifiers on this Mac."
                )
            }
            .padding(18)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Preferences are stored locally in macOS UserDefaults. Nothing is uploaded, sold, shared, or analyzed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 540)
    }

    private func privacyRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
