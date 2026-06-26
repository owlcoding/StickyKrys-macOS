import SwiftUI

/// Presents information about StickyKeys, its purpose, and its authors.
struct AboutView: View {
    private let website = URL(string: "http://bit.ly/sticckykeys")!

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: .icon1)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("StickyKeys")
                    .font(.title.bold())
                Text("One-shot modifier keys for macOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                informationRow(title: "Authors") {
                    Text("Pawel Maczewski & Marta Maczewslka")
                }

                informationRow(title: "Purpose") {
                    Text("StickyKeys makes keyboard shortcuts and typing easier by turning the right-side modifier keys into one-shot keys. We created it for health reasons when one of us temporarily could not use his left hand, allowing common key combinations to remain accessible with one hand.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                informationRow(title: "Website") {
                    Link("bit.ly/sticckykeys", destination: website)
                }
            }
            .padding(18)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(28)
        .frame(width: 500, height: 390)
    }

    private func informationRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(title)
                .font(.headline)
                .frame(width: 72, alignment: .trailing)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
