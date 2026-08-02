/// Pure display values for one rate-limit window row; nil when the window has no usage data.
struct RateLimitRowDisplay {
    let label: String
    let percent: Double
    let resetsInLabel: String

    init?(window: RateLimitWindow?, label: String) {
        guard let window, let percent = window.usedPercentage else { return nil }
        self.label = label
        self.percent = percent
        self.resetsInLabel = window.resetsInText.map { "resets \($0)" } ?? ""
    }
}
