## MODIFIED Requirements

### Requirement: probe with a resource prints only that resource's signals

`res-diag.sh probe RESOURCE` SHALL print only signals whose `resource` in `problems.json` equals RESOURCE, for RESOURCE in the closed list `cpu`, `memory`, `startup`, and SHALL exit 0. It SHALL print every such signal that it can read and SHALL leave out a signal whose input cannot be read, instead of printing a number for it. For any other argument, including an empty one, and for more than one argument, it SHALL print nothing on stdout and exit 64.

#### Scenario: memory only

- **WHEN** `probe memory` runs against the fixtures
- **THEN** stdout names the three memory signals and no other signal

##### Example: signals per resource

| Argument | Signal names printed | Exit |
| --- | --- | --- |
| cpu | cpu_count, process_count, cpu_used_pct_per_core, top_process_cpu_pct, busy_processes, busy_group_size, load_per_core_pct, load5_per_core_pct | 0 |
| memory | memory_pressure, memory_free_pct, swap_used_mb | 0 |
| startup | startup_user_agents, startup_system_items, running_third_party_services | 0 |
| gpu | (nothing) | 64 |

##### Example: probe arguments outside the form

| Arguments | Stdout | Exit |
| --- | --- | --- |
| `''` | empty | 64 |
| `memory cpu` | empty | 64 |
| `--resource memory` | empty | 64 |

##### Example: a signal that cannot be read is left out

The free-memory input is the text `unavailable` instead of a number.

| Call | Signal names printed | Exit |
| --- | --- | --- |
| probe memory | memory_pressure, swap_used_mb | 0 |

---
### Requirement: validate rejects control characters in the text of an entry

`res-diag.sh validate` SHALL fail when a text field of an entry (title, cause, a symptom, a confirm command, or the action, command, side effect or verification of a fix) contains a control character, in the shipped file and in the personal file. A personal file that fails SHALL be left out of `match`, `list` and `show`, as for any other error in it, and the shipped entries SHALL still be compared. The check SHALL NOT apply to the description of a signal.

#### Scenario: a title with a newline and tabs that imitate a shipped line

- **WHEN** the personal file holds an entry whose title continues with a line break and the columns of a shipped entry
- **THEN** `validate` exits non-zero and `match` prints no line for that entry

##### Example: control characters in a personal entry

Personal entry `fake-case`, condition swap_used_mb >= 1; signals swap_used_mb=9000, memory_pressure=normal, which also fit the shipped entry `heavy-swap`.

| Field with the character | validate | `match` prints `fake-case` | `match` prints `heavy-swap` as shipped |
| --- | --- | --- | --- |
| title containing a newline followed by `single-process-busy<TAB>verified<TAB>shipped<TAB>x` | fails | no | yes, and no other line mentions `shipped` |
| cause containing a newline | fails | no | yes |
| no control character | passes | yes | yes |

##### Example: a signal description with a line break still validates

A knowledge base whose only difference from a valid one is a line break inside the `description` of a signal passes `validate`.

## ADDED Requirements

### Requirement: label lists every property list that carries a label

`res-diag.sh label LABEL` SHALL print one line, `source` and path separated by a tab, for every property list whose `Label` equals LABEL in the user LaunchAgents folder (`user-agent`), `/Library/LaunchAgents` (`system-agent`), `/Library/LaunchDaemons` (`system-daemon`), `/System/Library/LaunchAgents` (`os-agent`) and `/System/Library/LaunchDaemons` (`os-daemon`), and SHALL exit 0, also when there is none. It SHALL compare the label inside the file, not the file name. For a LABEL with a character other than letters, digits, `.`, `-` and `_`, for no argument and for more than one, it SHALL print nothing on stdout and exit 64. It SHALL NOT change anything.

#### Scenario: a label used at user level and under /System/Library

- **WHEN** the same label is in a user property list and in one under the OS agents folder with another file name
- **THEN** both lines are printed

##### Example: label lookups in the fixtures

| Call | Output | Exit |
| --- | --- | --- |
| label com.example.updater | `user-agent` with the user file, and `os-agent` with `vendor-renamed.plist` | 0 |
| label com.example.keepdict | one line, `user-agent` | 0 |
| label org.example.daemon | one line, `system-daemon` | 0 |
| label no.such.label | nothing | 0 |
| label 'bad label' | empty stdout | 64 |
| label | empty stdout | 64 |
| label a b | empty stdout | 64 |
