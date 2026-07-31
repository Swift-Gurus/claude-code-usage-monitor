/**
 solid-name: LogViewerState
 solid-category: abstraction
 solid-description: Contract that provides both message display and task management state capabilities.
 */
protocol LogViewerState: MessageStateProviding, TaskStateProviding {}