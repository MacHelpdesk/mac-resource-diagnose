## Context

Verify round 3 of issue #2 (report on the issue, 12 rows; 8 block). Row 4, that `probe` followed by `match` measures twice, is behaviour of 0.1.0 that this issue does not change; it is filed separately.

## Goals / Non-Goals

**Goals:**

- The item `startup-fix` acts on is identified by file and by label, at the moment of asking and again at the moment of acting.
- What the user is asked about a process comes from the same reading that the final comparison uses.
- Nothing is widened without a requirement.

**Non-Goals:**

- Measuring once and matching the same snapshot. That is the separate issue.
- Running `kill`, `launchctl bootout` or `launchctl disable`.

## Decisions

### One subcommand answers "which files carry this label"

The check for a same-label item read the `startup` listing, which covers `/Library/LaunchAgents` and `/Library/LaunchDaemons` only. `res-diag.sh label LABEL` reads the label of every property list in five folders, including `/System/Library/LaunchAgents` and `/System/Library/LaunchDaemons`, and prints `source` and path for each match. The skill requires exactly one line, of source `user-agent`, with the approved path. More than one line means the label is shared; no line, or another path, means the file changed. In all those cases it does not act. The file name is not used: a label is what `launchctl disable` records.

About nine hundred property lists live in the two `/System/Library` folders. The subcommand first selects the files that contain the label as bytes and reads the label only of those.

### The same check twice, and the same plan

`startup-fix` runs the label check and `launchctl print` when it asks, and tells the user whether one command or two will run. Before acting it runs both again. A different result, or a different number of commands, means asking again.

### The recorded ps line is what the user is asked about

The line printed by `ps -o uid=,lstart=,comm= -p <pid>` names the program. The skill compares its last path segment with the `name` of the measured row and measures again when they differ, and it tells the user the program from that line.

### The control-character check is local to entries

`isText` is shared with the signal definitions and the never list. The check moves into `checkProblems`, so a knowledge base whose signal description has a line break validates as in 0.1.0.

## Implementation Contract

- `res-diag.sh label LABEL`: LABEL made of letters, digits, `.`, `-`, `_`; anything else, or a missing or second argument, exits 64 with empty stdout. Output: one line per property list, `source<TAB>path`, sources `user-agent`, `system-agent`, `system-daemon`, `os-agent`, `os-daemon`. Exit 0 also when nothing matches.
- Overrides for tests: `RES_DIAG_OS_AGENTS`, `RES_DIAG_OS_DAEMONS`.

## Risks / Trade-offs

- A label written in a property list in a form the byte search does not find (for example UTF-16 text) is missed. Labels are ASCII in practice; the skill still checks the loaded service with `launchctl print`.
- The subcommand was run on macOS 27.3 against the real folders; the actions it guards were not run.
