import AppKit

@MainActor
/// Handles first-run relocation of the app bundle into `/Applications`.
final class ApplicationLocationManager {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Prompts to move the app when it is launched from outside `/Applications`.
    /// - Returns: `true` when a relocated copy was launched and the current app should stop startup.
    func moveToApplicationsIfNeeded() -> Bool {
        let sourceURL = Bundle.main.bundleURL.standardizedFileURL
        log("startup source=\(sourceURL.path)")

        guard shouldMoveApp(at: sourceURL), let destinationURL = applicationsDestinationURL() else {
            log("relocation skipped source=\(sourceURL.path)")
            return false
        }

        log("relocation candidate destination=\(destinationURL.path)")

        let alert = NSAlert()
        alert.messageText = "Move StickyKeys to Applications?"
        alert.informativeText = informativeText(destinationURL: destinationURL) + "\n\nLog: \(logFileURL.path)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else {
            log("relocation cancelled by user")
            return false
        }

        do {
            log("copy starting from=\(sourceURL.path) to=\(destinationURL.path)")
            try moveApp(from: sourceURL, to: destinationURL)
            log("copy finished exists=\(fileManager.fileExists(atPath: destinationURL.path))")
            try launchRelocatedApp(at: destinationURL)
            log("relaunch command succeeded destination=\(destinationURL.path)")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 750_000_000)
                self.log("terminating original instance")
                NSApp.terminate(nil)
            }
            return true
        } catch {
            log("relocation failed error=\(error)")
            showMoveFailure(error)
            return false
        }
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
        let destinationDirectory = destinationURL.deletingLastPathComponent()

        if isWritableDirectory(destinationDirectory) {
            log("copy strategy=fileManager destinationDirectory=\(destinationDirectory.path)")
            try copyAppWithFileManager(from: sourceURL, to: destinationURL)
        } else {
            log("copy strategy=privilegedDitto destinationDirectory=\(destinationDirectory.path)")
            try copyAppWithAdministratorPrivileges(from: sourceURL, to: destinationURL)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CocoaError(.fileNoSuchFile)
        }
    }

    private func copyAppWithFileManager(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            log("removing existing destination=\(destinationURL.path)")
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func copyAppWithAdministratorPrivileges(from sourceURL: URL, to destinationURL: URL) throws {
        let command = [
            "/bin/rm -rf \(shellQuoted(destinationURL.path))",
            "/usr/bin/ditto \(shellQuoted(sourceURL.path)) \(shellQuoted(destinationURL.path))",
        ].joined(separator: " && ")

        let script = "do shell script \"\(appleScriptEscaped(command))\" with administrator privileges"
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        log("privileged copy terminated status=\(process.terminationStatus) output=\(output)")

        if process.terminationStatus != 0 {
            throw CocoaError(.fileWriteNoPermission)
        }
    }

    private func launchRelocatedApp(at destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", destinationURL.path]
        try process.run()
        process.waitUntilExit()
        log("open terminated status=\(process.terminationStatus)")

        if process.terminationStatus != 0 {
            throw CocoaError(.executableLoad)
        }
    }

    private func isWritableDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return fileManager.isWritableFile(atPath: url.path)
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func showMoveFailure(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "Could Not Move StickyKeys"
        alert.informativeText = "Move StickyKeys to /Applications manually, then open it again. \(error.localizedDescription)\n\nLog: \(logFileURL.path)"
        alert.runModal()
    }

    private var logFileURL: URL {
        let logsURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("StickyKeys", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("StickyKeys", isDirectory: true)
        return logsURL.appendingPathComponent("install.log")
    }

    private func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        NSLog("[StickyKeys install] %@", message)

        do {
            let fileURL = logFileURL
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if !fileManager.fileExists(atPath: fileURL.path) {
                try Data().write(to: fileURL)
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } catch {
            NSLog("[StickyKeys install] failed to write install log: %@", "\(error)")
        }
    }
}
