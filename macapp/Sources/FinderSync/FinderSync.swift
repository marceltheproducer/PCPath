// FinderSync.swift — PCPath Finder Sync extension.
//
// Adds the right-click "Quick Actions" items on macOS (Sonoma/Sequoia/Tahoe+),
// replacing the legacy Automator Services workflows which don't execute on
// Tahoe. The contextual menu only appears for items inside a monitored
// directory, so we monitor /Volumes (where every mapped network share lives).
//
// Conversion logic lives in PathConverter.swift (shared, unit-tested).

import Cocoa
import FinderSync
import os.log

final class FinderSync: FIFinderSync {

    private let log = OSLog(subsystem: "com.pcpath.PCPath.FinderSync", category: "menu")

    override init() {
        super.init()
        refreshMonitoredDirectories()
        // Re-scan when volumes mount/unmount so newly-connected shares are covered.
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(volumesChanged),
                       name: NSWorkspace.didMountNotification, object: nil)
        nc.addObserver(self, selector: #selector(volumesChanged),
                       name: NSWorkspace.didUnmountNotification, object: nil)
        nc.addObserver(self, selector: #selector(volumesChanged),
                       name: NSWorkspace.didRenameVolumeNotification, object: nil)
    }

    @objc private func volumesChanged(_ note: Notification) { refreshMonitoredDirectories() }

    /// Monitor the root plus every mounted volume. Each /Volumes/<share> is its
    /// own filesystem, and Finder Sync subtree monitoring can stop at mount
    /// boundaries — so we monitor the mount points themselves, not just /Volumes.
    private func refreshMonitoredDirectories() {
        var dirs: Set<URL> = [URL(fileURLWithPath: "/"),
                              URL(fileURLWithPath: "/Volumes")]
        if let vols = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") {
            for v in vols { dirs.insert(URL(fileURLWithPath: "/Volumes/\(v)")) }
        }
        FIFinderSyncController.default().directoryURLs = dirs
        os_log("PCPath monitoring %d directories", log: log, type: .info, dirs.count)
    }

    // MARK: Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "PCPath")
        // Offer the actions on selected items and on the folder background.
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return menu
        }

        let copyPC = NSMenuItem(title: "Copy as PC Path",
                                action: #selector(copyAsPCPath(_:)), keyEquivalent: "")
        let copyMac = NSMenuItem(title: "Copy Path",
                                 action: #selector(copyMacPath(_:)), keyEquivalent: "")
        let copyNames = NSMenuItem(title: "Copy Names",
                                   action: #selector(copyNames(_:)), keyEquivalent: "")
        let toMac = NSMenuItem(title: "Convert to Mac Path (from clipboard)",
                               action: #selector(convertToMacPath(_:)), keyEquivalent: "")
        for item in [copyMac, copyNames, copyPC, toMac] {
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    // MARK: Actions

    /// Selected Mac files → Windows/PC paths, newline-joined, onto the clipboard.
    @objc func copyAsPCPath(_ sender: AnyObject?) {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        let conv = PathConverter(config: PCPathConfig.load())
        let out = urls.map { conv.macToPC($0.path) }.joined(separator: "\n")
        setClipboard(out)
    }

    /// Selected items → their native Mac paths (/Volumes/…), newline-joined.
    /// No conversion — the Mac equivalent of the Windows "Copy as Path" verb.
    @objc func copyMacPath(_ sender: AnyObject?) {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        let out = urls.map { $0.path }.joined(separator: "\n")
        setClipboard(out)
    }

    /// Selected items → their names, one per line, onto the clipboard.
    @objc func copyNames(_ sender: AnyObject?) {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        let out = urls.map { PathConverter.baseName($0.path) }.joined(separator: "\n")
        setClipboard(out)
    }

    /// Read a Windows/PC path from the clipboard and convert it to a Mac path.
    /// (Operates on clipboard text, not the selection — same as the old action.)
    @objc func convertToMacPath(_ sender: AnyObject?) {
        guard let input = NSPasteboard.general.string(forType: .string), !input.isEmpty else { return }
        let conv = PathConverter(config: PCPathConfig.load())
        let out = input
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return conv.pcToMac(conv.stripWrappingQuotes(trimmed))
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !out.isEmpty else { return }
        setClipboard(out)
    }

    // MARK: Helpers

    private func selectedURLs() -> [URL] {
        if let sel = FIFinderSyncController.default().selectedItemURLs(), !sel.isEmpty {
            return sel
        }
        // Container background right-click: fall back to the targeted folder.
        if let target = FIFinderSyncController.default().targetedURL() {
            return [target]
        }
        return []
    }

    private func setClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        os_log("PCPath copied %d chars to clipboard", log: log, type: .info, text.count)
    }
}
