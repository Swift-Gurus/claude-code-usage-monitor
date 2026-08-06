import Foundation

/**
 solid-name: MetadataTextRendering
 solid-category: abstraction
 solid-description: Contract for rendering metadata dictionary values as display text.
 */
protocol MetadataTextRendering {
    func render(_ metadata: [String: Any]?) -> String?
}
