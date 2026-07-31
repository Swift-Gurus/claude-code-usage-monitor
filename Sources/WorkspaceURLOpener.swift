import AppKit

/**
 solid-name: WorkspaceURLOpener
 solid-category: service
 solid-description: Opens URLs through the system default handler.
 */
struct WorkspaceURLOpener: URLOpening {
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
