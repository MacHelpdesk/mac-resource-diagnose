## Why

The first verify round of issue #2 found that the split left four things loose: `probe` and `match` accept arguments outside their closed lists, a fix skill can act on a target other than the one the user approved, several skill texts read a missing result as a normal one, and a diagnose skill still had a sentence under which a command from a personal entry could run.

## What Changes

- `res-diag.sh probe` and `match` reject every argument outside their documented form with exit 64 and nothing on stdout: an empty resource, a second resource or signals file, a repeated `--resource`, an unknown option, an empty file name. **BREAKING** for callers that passed extra arguments, which 0.1.0 ignored.
- A fix skill identifies its target again before it acts: user id, start time and program before `kill`; the property-list path of the loaded service before a launchd item is disabled. After disabling it checks "unloaded" and "disabled" separately.
- Every skill reports "no known situation matched" instead of "normal", and the memory skills treat an `unknown` pressure as unread.
- A command from a personal entry runs only when the skill in use lists that action; the diagnose skills and the entry points say which files they may write.
- The restore commands `launchctl enable` and `launchctl bootstrap` join the table of consent commands and their owners.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `resource-scoped-measurement`: strict arguments for `probe` and `match`.
- `skill-boundaries`: exact headings, entry points without a resource argument, restore commands in the owner table, and five added requirements on what the skill texts state.

## Impact

- Changed files: plugin/scripts/res-diag.sh, plugin/scripts/kb.js, plugin/data/problems.json (one evidence note), the eight SKILL.md files, tests/test_probe.sh, tests/test_kb.sh, tests/test_skills.sh, README.md, CLAUDE.md, CHANGELOG.md.
- Version stays 0.2.0: nothing has been released from this branch.
