## Why

The third verify round of issue #2 found that `startup-fix` could still act on an item other than the approved one (it never compared the label inside the file again, and it looked for a same-label item in two of the four system folders only), that `cpu-fix` and `memory-fix` could ask about one process and record another, and that the second fix round had widened two things without a requirement: the control-character check and the read-only commands of the diagnose skills.

## What Changes

- `res-diag.sh label LABEL` lists every launchd property list that carries a label, in the user folder, the two `/Library` folders and the two `/System/Library` folders. Read-only.
- `startup-fix` runs it when asking and again before acting: the result must be exactly the approved user-level file, and the commands about to run must be the ones the user was told.
- `cpu-fix` and `memory-fix` take what they ask about from the recorded `ps` line and compare its program with the measured row.
- The control-character check applies to the text of entries only.
- The diagnose skills no longer list `id -u` or `launchctl print-disabled`.
- The requirement on `probe RESOURCE` says that a signal that cannot be read is left out.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `resource-scoped-measurement`: omitted signals, the scope of the control-character check, the `label` subcommand.
- `skill-boundaries`: target checks of the fix skills, commands the diagnose skills do not list.

## Impact

- Changed files: plugin/scripts/res-diag.sh, plugin/scripts/kb.js, the eight SKILL.md files, the three test scripts, two new fixture folders, README.md, CLAUDE.md, CHANGELOG.md.
- Version stays 0.2.0.
