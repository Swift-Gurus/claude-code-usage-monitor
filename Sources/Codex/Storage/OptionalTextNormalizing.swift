import Foundation

/**
 solid-name: OptionalTextNormalizing
 solid-category: abstraction
 solid-description: Contract for trimming optional text and rejecting empty values.
 */
protocol OptionalTextNormalizing {
    func normalize(_ value: String?) -> String?
}
