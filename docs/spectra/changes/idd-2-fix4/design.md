## Context

Verify round 4 of issue #2 (report on the issue, 9 rows; 7 block). All blocking rows concern the checks a fix skill makes before it acts, which earlier fix rounds added.

## Goals / Non-Goals

**Goals:**

- A label lookup that either read every property list or says it did not.
- Consent that is tied to the content of the property list and to one reading of the process.

**Non-Goals:**

- Protection against a property list replaced between the last check and the command, or a pid reused in that gap. The skills say the checks are best effort.

## Decisions

### Parse, then compare

`plugin/scripts/labels.js` runs once under the JavaScript engine of macOS, reads every `*.plist` of the five folders as a property list and compares the parsed `Label`. A label written with a character reference is found because the parser resolves it. Reading about nine hundred files this way took under a second on the test machine, so the byte search that preceded parsing is removed.

### Incomplete is an exit status

A folder that exists and cannot be listed, and a file that exists and is not a readable property list, are reported on stderr and make the exit status 5. A folder that does not exist and a symbolic link whose target does not exist are not items and are skipped. `startup-fix` acts only on exit 0.

### The checksum of the property list is part of what was approved

`cksum <path>` prints a checksum and a size. The skill records both when asking and compares before acting. A different value means the file changed, whatever its label and path.

### One reading for a process

`ps -o uid=,lstart=,comm=`, then `ps -o pcpu=,rss=`, then the first again, in one command. Equal first and third lines mean the figures between them belong to that process, within the one-second resolution of the start time. The skill asks with these three lines and no longer joins them to an earlier measurement by program name.

### Unknown pressure is a value

`memory_pressure` is the one signal with a value for "could not be read": it prints `unknown`, as in 0.1.0, and the skills read it that way. The requirement says so.

## Implementation Contract

- `res-diag.sh label LABEL`: stdout as before; exit 0 when every folder and file was read, 5 when not, 64 for a bad argument.
- `labels.js LABEL (SOURCE DIR)...` prints the matching lines and, last, a line `incomplete<TAB>path` for each unreadable folder or file; `res-diag.sh` moves those lines to stderr.

## Risks / Trade-offs

- On a Mac with a damaged property list in one of the five folders `startup-fix` will not disable anything until the user looks at that file. That is the conservative direction.
- The read-only commands were run on macOS 27.3. `kill` and the launchd actions were not.
