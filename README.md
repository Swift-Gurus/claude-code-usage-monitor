# Claude Code Usage Monitor

A lightweight macOS menu bar app that tracks your [Claude Code](https://docs.anthropic.com/en/docs/claude-code) spending, code changes, and active sessions.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## What It Does

- Displays today's cost in the menu bar with active agent count
- Shows a popover with **Day / Week / Month** breakdowns:
  - API cost (USD)
  - Lines added / removed
- **Live agent tracking** — shows all running Claude Code sessions:
  - Model name and agent name
  - Context window usage (color-coded)
  - Session cost and duration
  - Working directory
  - Active vs idle status with idle duration
- Auto-updates in real time via FSEvents
- Automatically installs and upgrades the statusline tracking on launch

## How It Works

Claude Code supports a [statusline](https://docs.anthropic.com/en/docs/claude-code/statusline) — a shell script that receives session data as JSON via stdin. This app installs a small tracking snippet into your statusline script that writes:

- `~/.claude/usage/YYYY-MM-DD/{pid}.dat` — cost and line changes (for aggregate stats)
- `~/.claude/usage/YYYY-MM-DD/{pid}.agent.json` — live session metadata (for agent tracking)

The menu bar app monitors that directory with FSEvents and aggregates the results.

If you already have a custom statusline script, only the tracking snippet is injected (marked with `# --- ClaudeUsageBar tracking ---`). Your existing display output is left untouched. The app auto-upgrades the snippet when new fields are added.

## Requirements

- macOS 14 (Sonoma) or later
- [jq](https://jqlang.github.io/jq/) — used by the statusline script to parse JSON
  ```bash
  brew install jq
  ```

## Install

### Option 1: Build from source

```bash
git clone https://github.com/Swift-Gurus/claude-code-usage-monitor.git
cd claude-code-usage-monitor
./scripts/package-app.sh
cp -R ClaudeUsageBar.app /Applications/
open /Applications/ClaudeUsageBar.app
```

### Option 2: Run directly with Swift

```bash
git clone https://github.com/Swift-Gurus/claude-code-usage-monitor.git
cd claude-code-usage-monitor
swift run
```

## Uninstall

1. Quit the app from the popover menu
2. Delete the app: `rm -rf /Applications/ClaudeUsageBar.app`
3. (Optional) Remove tracking from your statusline script — delete the block between `# --- ClaudeUsageBar tracking ---` and `# --- end ClaudeUsageBar tracking ---`
4. (Optional) Remove usage data: `rm -rf ~/.claude/usage`

## Project Structure

```
Sources/
  ClaudeUsageBarApp.swift    # App entry point, menu bar setup
  PopoverView.swift          # Popover UI with period breakdowns and agent sections
  UsageData.swift            # Reads and aggregates .dat files
  AgentTracker.swift         # Tracks live agents via .agent.json files + PID liveness
  UsageMonitor.swift         # FSEvents watcher for live updates
  StatuslineInstaller.swift  # Installs/injects/upgrades statusline tracking
  Resources/
    statusline-command.sh    # Full statusline script (used for fresh installs)
scripts/
  package-app.sh             # Builds and packages the .app bundle
```

## License

MIT — see [LICENSE](LICENSE).