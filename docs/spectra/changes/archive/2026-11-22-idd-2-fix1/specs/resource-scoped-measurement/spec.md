## MODIFIED Requirements

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
