## Context

Verify round 1 of issue #2 (report on the issue, 22 rows). Rows 1 to 9 block; rows 10 to 20 are fixed in the same round. The eight skills are prose read by a model, so a requirement about a skill is checked as text: the file contains a sentence or a command, or does not.

## Goals / Non-Goals

**Goals:**

- No argument outside the documented form changes what `probe` or `match` measures or compares.
- A fix skill cannot act on a process or a launchd item that differs from the one shown to the user.
- A skill never turns "not measured" or "not matched" into "fine".

**Non-Goals:**

- Running `kill` or `launchctl bootout` to verify them. They stay unverified.
- Checking what a model does after reading a skill. The tests check text.

## Decisions

### Arguments are strict instead of first-wins or last-wins

0.1.0 read the first positional argument of `match` and ignored the rest; the first version of this branch read the last. Neither is stated anywhere. Rejecting everything outside the documented form removes the question, and a caller that builds an argument from an unset variable gets an error instead of an unscoped result.

### Identity of a process is user id, start time and program

`LC_ALL=C ps -o uid=,lstart=,comm= -p <pid>` prints the three values. A process that reuses the pid has a later start time. `lstart` is printed in the C locale, so the skill compares two strings from the same command and never parses them.

### The loaded launchd service is checked by its property-list path

`launchctl print gui/<uid>/<label>` prints a `path =` line. The skill disables an item only when that path is the approved file under `~/Library/LaunchAgents/`. When a label is loaded from elsewhere, the skill stops.

### Unloaded and disabled are two facts

`launchctl print` no longer finding the service shows it is unloaded. `launchctl print-disabled gui/<uid>` listing the label as disabled shows it will not start at the next login. The skill reports each separately.

### A personal entry never widens a skill

The sentence "commands from a personal entry run after the user agrees" is replaced. Such a command runs only when it is one of the actions the skill in use lists under done-directly or asked-first; anything else is shown and not run. `res-diag.sh show` says the same.

### Correction to the archived design of idd-2-split-resource-skills

That design and its task 2.1 say the usage text of `res-diag.sh` ends at the first empty comment line. The code, CLAUDE.md and the test end it at the second: the first empty line follows the two-line summary. The code is right. The archived files are not edited; this paragraph is the correction.

## Implementation Contract

- `res-diag.sh probe [cpu|memory|startup]` and `res-diag.sh match [--resource R] [SIGNALS_FILE]`: any other argument list exits 64 with empty stdout.
- Tests observe which probes ran through stub `ps`, `plutil` and `launchctl` programs on PATH that append their name to a file.
- Skill requirements are checked by literal text in tests/test_skills.sh.

## Risks / Trade-offs

- A script that called `match FILE extra` now fails. No shipped skill or test did.
- The identity check adds one `ps` call before a `kill`; the two launchd checks add two read-only calls.
- The read-only commands were run once on macOS 27.3 to see their output form. The actions they guard were not run.
