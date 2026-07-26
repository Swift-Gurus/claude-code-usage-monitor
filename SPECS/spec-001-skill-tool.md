---
number: SPEC-001
feature: skill tool render
status: done
blocked-by: []
blocking: []
---


In our log viewer we have logs, where there are tools_use are shown
we have multiple different tools, they are behind enum
each tool has its own view, what is selected by parent wrapper view.
each tool is already expandable, so skill tool should be expandable as well.

we need to explore jsonl messages in the ~/.claude/projects/xxx
to find proper tool definition, our parser should be able to parse into proper SkillTool data
that is a part of LogMessage property behind enum already.

