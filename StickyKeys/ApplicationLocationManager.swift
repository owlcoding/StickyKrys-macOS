import AppKit

@MainActor
/// Handles first-run relocation of the app bundle into `/Applications`.
final class ApplicationLocationManager {
    private let fileManager: FileManager
    private let workspace: NSWorkspace

    init(
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared
    ) {
        self.fileManager = fileManager
        self.workspace = workspace
    }

    /// Prompts to move the app when it is launched from outside `/Applications`.
    /// - Returns: `true` when a relocated copy was launched and the current app should stop startup.
    func moveToApplicationsIfNeeded() -> Bool {
        #if DEBUG
        return false
        #else
        let sourceURL = Bundle.main.bundleURL.standardizedFileURL
        guard shouldMoveApp(at: sourceURL), let destinationURL = applicationsDestinationURL() else {
            return false
        }

        let alert = NSAlert()
        alert.messageText = "Move StickyKeys to Applications?"
        alert.informativeText = informativeText(destinationURL: destinationURL)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        do {
            try moveApp(from: sourceURL, to: destinationURL)
            try launchRelocatedApp(at: destinationURL)
            NSApp.terminate(nil)
            return true
        } catch {
            showMoveFailure(error)
            return false
        }
        #endif
    }

    private func shouldMoveApp(at sourceURL: URL) -> Bool {
        guard sourceURL.pathExtension == "app" else { return false }
        return !isInsideApplicationsDirectory(sourceURL)
    }

    private func isInsideApplicationsDirectory(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        return applicationDirectories().contains { applicationsURL in
            standardizedURL.path.hasPrefix(applicationsURL.standardizedFileURL.path + "/")
        }
    }

    private func applicationDirectories() -> [URL] {
        var urls = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
        urls.append(contentsOf: fileManager.urls(for: .applicationDirectory, in: .userDomainMask))
        return urls
    }

    private func applicationsDestinationURL() -> URL? {
        fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
            .first?
            .appendingPathComponent(Bundle.main.bundleURL.lastPathComponent, isDirectory: true)
    }

    private func informativeText(destinationURL: URL) -> String {
        if fileManager.fileExists(atPath: destinationURL.path) {
            return "StickyKeys works best from /Applications. An existing copy will be replaced."
        }
        return "StickyKeys works best from /Applications, especially when using Launch at Login and macOS privacy permissions."
    }

    private func moveApp(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func launchRelocatedApp(at destinationURL: URL) throws {
        if !workspace.open(destinationURL) {
            throw CocoaError(.executableLoad)
        }
    }

    private func showMoveFailure(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "Could Not Move StickyKeys"
        alert.informativeText = "Move StickyKeys to /Applications manually, then open it again."
        alert.runModal()
    }
}
