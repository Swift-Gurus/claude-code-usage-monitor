import Foundation

/**
 solid-name: MetadataTextRenderer
 solid-category: utility
 solid-description: Renders metadata dictionary values as sorted display text.
 */
struct MetadataTextRenderer: MetadataTextRendering {
    func render(_ metadata: [String: Any]?) -> String? {
        guard let metadata, !metadata.isEmpty else { return nil }
        return metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}
