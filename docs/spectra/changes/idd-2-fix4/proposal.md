## Why

The fourth verify round of issue #2 found that the label lookup added in the third fix round could miss a file (it searched for the label as bytes before parsing) and could not say that it had not read everything, and that two checks still accepted a replaced target: a property list replaced at the same path with the same label, and a process with the same program name that took over a pid.

## What Changes

- `res-diag.sh label` parses every property list in the five folders and compares the parsed label. When a folder or a file that exists cannot be read it names it on stderr and exits 5.
- `startup-fix` uses the result only when the exit status is 0, records the checksum of the property list when asking, and compares it again before acting.
- `cpu-fix` and `memory-fix` read identity, figures and identity again in one command and take everything they ask about from that reading.
- `startup-diagnose` does not list `label`.
- The requirement on unreadable signals names the one signal that prints `unknown` instead of being left out.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `resource-scoped-measurement`: the label lookup and the wording on unreadable signals.
- `skill-boundaries`: target checks, commands a diagnose skill does not list, and how the eight skill folders are counted.

## Impact

- Changed files: plugin/scripts/res-diag.sh, plugin/scripts/kb.js, new plugin/scripts/labels.js, the eight SKILL.md files, the three test scripts, fixtures, README.md, CLAUDE.md, CHANGELOG.md.
- Version stays 0.2.0.
