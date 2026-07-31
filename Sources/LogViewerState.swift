/**
 solid-name: LogViewerState
 solid-category: abstraction
 solid-description: Contract that consolidates message, task, and statistics state capabilities.
 */
protocol LogViewerState: MessageStateProviding, TaskStateProviding, StatsStateProviding {}