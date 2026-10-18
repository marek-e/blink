#if DEBUG || BLINK_TESTING
import AppKit

/// Debug builds only: writes PNGs of Blink's visible windows when asked, for UI review without
/// screen-recording permission. Launch with `-BlinkSnapshotDirectory <dir>`, then post the
/// distributed notification `BlinkWriteSnapshots`.
@MainActor
enum DebugSnapshots {
    static func install() {
        guard let path = UserDefaults.standard.string(forKey: "BlinkSnapshotDirectory") else { return }
        let directory = URL(filePath: path, directoryHint: .isDirectory)
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("BlinkWriteSnapshots"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { write(to: directory) }
        }
    }

    private static func write(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (index, window) in NSApp.windows.enumerated() where window.isVisible {
            guard let view = window.contentView?.superview ?? window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
            else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let name = window.title.isEmpty ? "window-\(index)" : window.title.replacingOccurrences(of: " ", with: "-")
            try? rep.representation(using: .png, properties: [:])?.write(to: directory.appending(path: "\(name).png"))
        }
    }
}
#endif
