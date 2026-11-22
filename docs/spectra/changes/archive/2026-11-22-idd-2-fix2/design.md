## Context

Verify round 2 of issue #2 (report on the issue, 18 rows; rows 1 to 6 block). The maintainer asked to continue and did not choose among the three direction questions of that report; the Decision comment on the issue records that this change follows the recommendations given with the report.

## Goals / Non-Goals

**Goals:**

- State honestly what the check before `kill` can and cannot guarantee.
- Never disable a label that also names a system-level item.
- Keep a way to disable a user-level item that is not loaded.

**Non-Goals:**

- A guarantee that `kill` reaches the approved process. A shell cannot bind a signal to a process identity.
- Running `kill`, `launchctl bootout` or `launchctl disable`. They stay unverified.

## Decisions

### Compare and send in one command; call it best effort

`[ "$(LC_ALL=C ps -o uid=,lstart=,comm= -p <pid>)" = "<recorded line>" ] && kill <pid>` leaves only the time between two system calls, where the earlier text left a whole model turn. The start time has a resolution of one second and the gap is not zero, so the skill says the check is best effort and recommends quitting in the app first. The goal written in the design of idd-2-fix1, "cannot act on a process that differs from the one shown", was stronger than what is possible; this paragraph corrects it.

### A label that exists at both levels is left to the user

`launchctl disable gui/<uid>/<label>` records an override for the label, so a system-level item with the same label would also stop loading for this user. The skill looks for the label under `system-agent` and `system-daemon` in `res-diag.sh startup` and does not act when it is there.

### Three cases before disabling

Loaded from the approved file: `bootout`, and only when that succeeds, `disable`. Not loaded: `disable` alone, after checking that the approved file is still under `~/Library/LaunchAgents/`; the user is told that only this one step will run. Loaded from elsewhere: nothing.

### Personal entries are read, not run

"Only actions the skill lists" still let a string that begins with a listed command and continues with something else through. The rule is now that no command string from a personal entry is run as written; the skill runs only the commands written in the skill itself.

### Control characters are rejected in entry text

A newline or a tab in a title could add a line or a column to the output of `match` and make a personal entry look shipped. `validate` rejects them in every text field, so a personal file that has them is left out as any other invalid personal file is.

### Labels in commands

A label is taken from a property list written by other software. The skills put it into a command only when it consists of letters, digits, `.`, `-` and `_`, and put a path in single quotes.

## Implementation Contract

- `kb.js` `checkProblems`: a text field with a character below U+0020 or U+007F is an error.
- Tests check an empty stdout by writing it to a file and testing that the file has no bytes.
- A boundary heading is the heading alone or the heading followed by `：只有這` and a count and `件`.

## Risks / Trade-offs

- A personal entry with a tab or newline in its text stops validating. The file is then left out with a message, as before for other errors.
- The one-line compare-and-send was run on macOS 27.3 with a harmless command in place of `kill`; `kill` itself was not run.
