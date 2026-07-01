import SwiftUI

/// Presents information about StickyKeys, its purpose, and its authors.
struct AboutView: View {
    private let website = URL(string: "http://bit.ly/sticckykeys")!
    let showPrivacyPolicy: () -> Void

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
                informationRow(title: "Author") {
                    Text("Pawel Maczewski")
                }

                informationRow(title: "Purpose") {
                    Text("StickyKeys makes keyboard shortcuts, typing and mouse-clicks easier by turning the right-side modifier keys into one-shot keys. It was created for accessibility reasons when I temporarily could not use my left hand, allowing common key combinations to remain accessible with one hand.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                informationRow(title: "Website") {
                    Link("bit.ly/sticckykeys", destination: website)
                }
            }
            .padding(18)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))

            Button("Privacy Policy", action: showPrivacyPolicy)
        }
        .padding(28)
        .frame(width: 500, height: 430)
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
