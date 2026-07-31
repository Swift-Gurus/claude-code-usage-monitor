/**
 solid-name: TaskCompletionPercent
 solid-category: model
 solid-description: Calculates a completion percentage from completed and total counts.
 */
struct TaskCompletionPercent {
    let value: Int

    init(completed: Int, total: Int) {
        guard total > 0 else { value = 0; return }
        value = Int(Double(completed) / Double(total) * 100)
    }
}
