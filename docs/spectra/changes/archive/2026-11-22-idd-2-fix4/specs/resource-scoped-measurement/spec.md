## MODIFIED Requirements

### Requirement: probe with a resource prints only that resource's signals

`res-diag.sh probe RESOURCE` SHALL print only signals whose `resource` in `problems.json` equals RESOURCE, for RESOURCE in the closed list `cpu`, `memory`, `startup`, and SHALL exit 0. It SHALL print every such signal that it can read. A signal whose input cannot be read SHALL be left out instead of printed as a number, with one exception: `memory_pressure` SHALL be printed with the value `unknown`. For any other argument, including an empty one, and for more than one argument, it SHALL print nothing on stdout and exit 64.

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

##### Example: an unreadable memory pressure is printed as unknown

The pressure input is the text `unavailable`.

| Call | Line printed for the pressure | Exit |
| --- | --- | --- |
| probe memory | `memory_pressure=unknown` | 0 |

---
### Requirement: label lists every property list that carries a label

`res-diag.sh label LABEL` SHALL print one line, `source` and path separated by a tab, for every property list whose parsed `Label` equals LABEL in the user LaunchAgents folder (`user-agent`), `/Library/LaunchAgents` (`system-agent`), `/Library/LaunchDaemons` (`system-daemon`), `/System/Library/LaunchAgents` (`os-agent`) and `/System/Library/LaunchDaemons` (`os-daemon`). It SHALL compare the label after parsing the file, not the file name and not the bytes of the file. It SHALL exit 0 when it read every folder and every property list in them, also when none matches. When a folder that exists cannot be listed, or a file that exists is not a readable property list, it SHALL name it on stderr and exit 5, and still print the matches it found. A folder that does not exist and a symbolic link whose target does not exist SHALL be skipped. For a LABEL with a character other than letters, digits, `.`, `-` and `_`, for no argument and for more than one, it SHALL print nothing on stdout and exit 64. It SHALL NOT change anything.

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

##### Example: a label written with a character reference is found

`agents_os/encoded.plist` writes its label as `com&#46;example.sync-agent`.

| Call | Output | Exit |
| --- | --- | --- |
| label com.example.sync-agent | `user-agent` with the user file, and `os-agent` with `encoded.plist` | 0 |

##### Example: an unreadable property list makes the lookup incomplete

The OS daemons folder is replaced by a folder that holds a file `broken.plist` that is not a property list and a symbolic link `gone.plist` whose target does not exist.

| Call | Stdout | Stderr names | Exit |
| --- | --- | --- | --- |
| label com.example.keepdict | one line, `user-agent` | `broken.plist`, not `gone.plist` | 5 |
