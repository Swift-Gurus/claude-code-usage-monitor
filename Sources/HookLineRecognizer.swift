/// Which hook-shaped JSONL line kind a raw entry is, if any.
enum HookLineKind {
    case progress
    case stopHookSummary
    case additionalContext
    case attachment(attType: String, att: [String: Any])
}

/**
 solid-name: HookLineRecognizing
 solid-category: abstraction
 solid-description: Contract for classifying a raw JSONL entry as one of the known hook-shaped line kinds, or nil if it isn't hook-shaped at all.
 */
protocol HookLineRecognizing {
    func recognize(type: String, raw: [String: Any]) -> HookLineKind?
}

/**
 solid-name: HookLineRecognizer
 solid-category: service
 solid-description: Pure classification of raw JSONL entries with no side effects.
 */
struct HookLineRecognizer: HookLineRecognizing {
    func recognize(type: String, raw: [String: Any]) -> HookLineKind? {
        if type == "progress",
           let data = raw["data"] as? [String: Any],
           (data["type"] as? String) == "hook_progress" {
            return .progress
        }

        if type == "system", (raw["subtype"] as? String) == "stop_hook_summary" {
            return .stopHookSummary
        }

        if type == "attachment", let att = raw["attachment"] as? [String: Any] {
            if (att["type"] as? String) == "hook_additional_context" {
                return .additionalContext
            }
            if let attType = att["type"] as? String {
                return .attachment(attType: attType, att: att)
            }
        }

        return nil
    }
}
