import Foundation

/**
 solid-name: URLOpening
 solid-category: abstraction
 solid-description: Contract for opening a URL in the system's default handler.
 */
protocol URLOpening {
    func open(_ url: URL)
}
