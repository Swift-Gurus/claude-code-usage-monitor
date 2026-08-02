import Foundation

/// Caches per-file day-bucketed stats by mtime, so repeated reloads only re-parse
/// files that actually changed.
final class StatsFileCache {
    private var entries: [URL: (mtime: Date?, statsByDay: [String: SessionStats])] = [:]

    func statsByDay(for url: URL, mtime: Date?, computeIfNeeded: () -> [String: SessionStats]) -> [String: SessionStats] {
        if let cached = entries[url], cached.mtime == mtime {
            return cached.statsByDay
        }
        let computed = computeIfNeeded()
        entries[url] = (mtime: mtime, statsByDay: computed)
        return computed
    }
}
