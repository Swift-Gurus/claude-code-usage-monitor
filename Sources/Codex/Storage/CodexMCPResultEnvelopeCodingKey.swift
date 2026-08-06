import Foundation

/**
 solid-name: CodexMCPResultEnvelopeCodingKey
 solid-category: model
 solid-description: Defines serialized field names for operation completion outcomes.
 */
enum CodexMCPResultEnvelopeCodingKey: String, CodingKey {
    case success = "Ok"
    case failure = "Err"
}
