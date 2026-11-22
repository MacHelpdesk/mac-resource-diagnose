## Why

The second verify round of issue #2 found that the target checks added in the first fix round were incomplete or too strict: a `kill` could still reach a process other than the approved one, `launchctl disable` acts on a label and not on the approved file, an item that is not loaded could no longer be disabled, and the entry points lost two read-only commands that 0.1.0 allowed.

## What Changes

- `cpu-fix` and `memory-fix` compare and send in one command, require the process to belong to the current user, list `id -u` among the commands they run directly, and say that the comparison is best effort.
- `startup-fix` distinguishes three cases before it acts (loaded from the approved file, not loaded, loaded from elsewhere), does not act when the same label also exists at system level, does not go on to `disable` after a failed `bootout`, and tells "service not found" from "query failed" afterwards.
- The entry points list `launchctl print` and `plutil -p` again.
- A command string from a personal entry is never run as written, in any skill.
- `validate` rejects control characters in the text of an entry.
- A launchd label is put into a command only when it is made of safe characters.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `resource-scoped-measurement`: one added requirement on control characters in entries.
- `skill-boundaries`: heading suffix, target checks, personal entries, and one added requirement on the read-only commands of the entry points and on labels in commands.

## Impact

- Changed files: plugin/scripts/kb.js, plugin/scripts/res-diag.sh (header comment), plugin/data/problems.json (one command), the eight SKILL.md files, the three test scripts, README.md, CLAUDE.md, CHANGELOG.md.
- Version stays 0.2.0.
