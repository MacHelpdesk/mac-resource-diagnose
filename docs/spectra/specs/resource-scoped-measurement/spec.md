# resource-scoped-measurement Specification

## Purpose

The tool measures three resources: CPU, memory, and items that start at login. This capability fixes which signals and knowledge-base entries belong to which resource, so that one resource can be measured and matched without the others, and so that calls written for 0.1.0 keep their output.

## Requirements

### Requirement: probe with a resource prints only that resource's signals

`res-diag.sh probe RESOURCE` SHALL print exactly the signals whose `resource` in `problems.json` equals RESOURCE, for RESOURCE in the closed list `cpu`, `memory`, `startup`, and SHALL exit 0. For any other argument, including an empty one, and for more than one argument, it SHALL print nothing on stdout and exit 64.

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

---
### Requirement: probe without a resource is unchanged

`res-diag.sh probe` without an argument SHALL print the signals of all three resources, with the same names and values that the three scoped calls print for the same input.

#### Scenario: all signals

- **WHEN** `probe` runs against the fixtures
- **THEN** its lines are the lines of `probe cpu`, `probe memory` and `probe startup` together

##### Example: unscoped probe equals the three scoped probes

Sorted output of `probe` equals the sorted concatenation of `probe cpu`, `probe memory` and `probe startup` for one fixture set, and has 14 lines.

---
### Requirement: every signal and shipped entry names its resource

`res-diag.sh validate` SHALL fail when a signal has no `resource` or one outside `cpu`, `memory`, `startup`; when an entry has a `resource` outside `cpu`, `memory`, `startup`, `general`; and when an entry whose `resource` is `cpu`, `memory` or `startup` has a condition on a signal of another resource. Every entry in the shipped `problems.json` SHALL have a `resource`.

#### Scenario: an entry tagged cpu uses a memory signal

- **WHEN** a knowledge base holds an entry with `resource` `cpu` and a condition on `swap_used_mb`
- **THEN** `validate` exits non-zero and names the entry

##### Example: resource fields that validate and that do not

| Knowledge base | validate |
| --- | --- |
| shipped file | passes |
| signal without `resource` | fails |
| signal with `resource` `disk` | fails |
| entry with `resource` `network` | fails |
| entry `resource` `cpu` with a condition on `swap_used_mb` | fails |
| entry `resource` `general` with conditions on `load_per_core_pct` and `swap_used_mb` | passes |

##### Example: shipped entries and their resources

| Entry | resource |
| --- | --- |
| single-process-busy | cpu |
| many-parallel-jobs | cpu |
| load-above-cpu | general |
| memory-pressure | memory |
| heavy-swap | memory |
| many-startup-agents | startup |
| many-background-services | startup |

---
### Requirement: match can be limited to one resource

`res-diag.sh match --resource R [SIGNALS_FILE]` SHALL print only matching entries whose resource is R, for R in the closed list `cpu`, `memory`, `startup`, `general`, with the same columns as `match` and exit 3 when none matches. Without a signals file it SHALL run the probe of that resource and no other; for `general` it SHALL run the unscoped probe. Without `--resource`, `match` SHALL compare every entry as in 0.1.0. It SHALL print nothing on stdout and exit 64 for an R outside the list, including an empty one; for `--resource` without a value or given twice; for a second signals file; for an empty file name; and for any other argument that begins with `-`.

#### Scenario: one signals file, three scopes

- **WHEN** a signals file fits a CPU entry and a memory entry
- **THEN** `match --resource cpu` prints only the CPU entry, `match --resource memory` only the memory entry, and `match` both

##### Example: matching by resource

Signals: top_process_cpu_pct=185, busy_group_size=1, load_per_core_pct=60, cpu_used_pct_per_core=50, memory_pressure=normal, swap_used_mb=9000, startup_user_agents=12, running_third_party_services=3.

| Call | Entry ids | Exit |
| --- | --- | --- |
| match FILE | heavy-swap, many-startup-agents, single-process-busy | 0 |
| match --resource cpu FILE | single-process-busy | 0 |
| match --resource memory FILE | heavy-swap | 0 |
| match FILE --resource startup | many-startup-agents | 0 |
| match --resource general FILE | (none) | 3 |
| match --resource gpu FILE | (none) | 64 |

##### Example: the cross-resource entry stays out of the cpu scope

Signals: top_process_cpu_pct=40, busy_group_size=1, load_per_core_pct=900, cpu_used_pct_per_core=70.

| Call | Entry ids | Exit |
| --- | --- | --- |
| match FILE | load-above-cpu | 0 |
| match --resource general FILE | load-above-cpu | 0 |
| match --resource cpu FILE | (none) | 3 |

##### Example: match arguments outside the form

FILE fits single-process-busy; OTHER is a second readable file.

| Arguments | Stdout | Exit |
| --- | --- | --- |
| `--resource '' FILE` | empty | 64 |
| `--resource` | empty | 64 |
| `--resource gpu --resource cpu FILE` | empty | 64 |
| `--resource cpu --resource cpu FILE` | empty | 64 |
| `FILE OTHER` | empty | 64 |
| `--resource=cpu FILE` | empty | 64 |
| `''` | empty | 64 |

##### Example: probes run by a match without a file

`ps`, `plutil` and `launchctl` are replaced by programs that record their name; no process list, launchctl listing or signals file is given.

| Call | Programs recorded |
| --- | --- |
| match --resource memory | none |
| match --resource cpu | ps |
| match --resource startup | plutil, launchctl |
| match --resource general | ps, plutil, launchctl |
| match | ps, plutil, launchctl |

---
### Requirement: a personal entry without a resource counts as general

An entry in the personal knowledge base that has no `resource` SHALL pass `validate`, SHALL appear in `match` without `--resource` and in `match --resource general`, and SHALL NOT appear in `match --resource cpu`, `memory` or `startup`.

#### Scenario: a file written for 0.1.0

- **WHEN** the personal file holds one entry without `resource` whose condition holds
- **THEN** the unscoped match and the general match print it, and the cpu match does not

##### Example: local entry without a resource

Personal entry `my-case`, no `resource`, condition swap_used_mb >= 1; signals swap_used_mb=5, memory_pressure=normal.

| Call | Contains my-case |
| --- | --- |
| validate | passes |
| match FILE | yes |
| match --resource general FILE | yes |
| match --resource memory FILE | no |

---
### Requirement: show names the resource of an entry

`res-diag.sh show ID` SHALL print one line `resource: R`, where R is the entry's resource or `general` when the entry has none.

#### Scenario: a memory entry

- **WHEN** `show heavy-swap` runs
- **THEN** its output has the line `resource: memory`

##### Example: show prints the resource

| Call | Line present |
| --- | --- |
| show heavy-swap | resource: memory |
| show load-above-cpu | resource: general |

---
### Requirement: validate rejects control characters in the text of an entry

`res-diag.sh validate` SHALL fail when a text field of an entry (title, cause, a symptom, a confirm command, or the action, command, side effect or verification of a fix) contains a control character, in the shipped file and in the personal file. A personal file that fails SHALL be left out of `match`, `list` and `show`, as for any other error in it.

#### Scenario: a title with a newline and tabs that imitate a shipped line

- **WHEN** the personal file holds an entry whose title continues with a line break and the columns of a shipped entry
- **THEN** `validate` exits non-zero and `match` prints no line for that entry

##### Example: control characters in a personal entry

Personal entry `fake-case`, condition swap_used_mb >= 1, signals swap_used_mb=5.

| Field with the character | validate | Lines of `match` that mention `shipped` |
| --- | --- | --- |
| title containing a newline followed by `single-process-busy<TAB>verified<TAB>shipped<TAB>x` | fails | 0 |
| cause containing a newline | fails | 0 |
| no control character | passes | 0 |
