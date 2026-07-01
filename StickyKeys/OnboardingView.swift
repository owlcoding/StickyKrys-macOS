import Combine
import SwiftUI

@MainActor
final class OnboardingTestFieldState: ObservableObject {
    @Published var sampleText = "Try StickyKeys here"
}

/// Pierwszorazowy przewodnik po działaniu StickyKeys z polem do testowania skrótów.
struct OnboardingView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var modifierState: ModifierState
    @ObservedObject var testFieldState: OnboardingTestFieldState

    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to StickyKeys")
                    .font(.title.bold())
                Text("Pick the side that is easier for you to reach, then try each sticky modifier in the field below.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("Choose Your Side") {
                HStack(spacing: 14) {
                    Text("More accessible side")
                        .frame(width: 150, alignment: .leading)

                    Picker("More accessible side", selection: $settings.triggerSide) {
                        ForEach(TriggerKeySide.allCases) { side in
                            Text(side.displayName).tag(side)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 270)
                }
            }

            section("Try It") {
                VStack(alignment: .leading, spacing: 12) {
                    instructionRow(
                        number: 1,
                        title: "Press \(sideLabel) Shift once",
                        detail: "Then type any letter or number. Shift is applied to that one keypress."
                    )
                    instructionRow(
                        number: 2,
                        title: "Press \(sideLabel) Shift twice quickly",
                        detail: "Shift Lock stays on for following keys. Press \(sideLabel) Shift again to turn it off."
                    )
                    instructionRow(
                        number: 3,
                        title: "Try \(sideLabel) Option",
                        detail: "Press \(sideLabel) Option once, then type a key that normally produces an alternate character."
                    )
                    instructionRow(
                        number: 4,
                        title: "Try \(sideLabel) Command",
                        detail: "Press \(sideLabel) Command once, then press A. The text field should select its text."
                    )
                }
            }

            section("Test Field") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Type here", text: $testFieldState.sampleText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)

                    HStack {
                        Text(modifierState.statusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset Text") {
                            testFieldState.sampleText = "Try StickyKeys here"
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    finish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 620)
        .frame(minHeight: 650)
    }

    private var sideLabel: String {
        settings.triggerSide.keyLabelPrefix
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func instructionRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.bold())
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
