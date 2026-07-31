/**
 solid-name: DiffLines
 solid-category: model
 solid-description: Encapsulates both versions of a text diff with a size indicator.
 */
struct DiffLines {
    let old: [String]
    let new: [String]
    let isLarge: Bool

    init(oldText: String, newText: String) {
        old = oldText.isEmpty ? [] : oldText.components(separatedBy: "\n")
        new = newText.isEmpty ? [] : newText.components(separatedBy: "\n")
        isLarge = old.count + new.count > 120
    }
}
