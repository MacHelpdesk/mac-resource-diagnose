## MODIFIED Requirements

### Requirement: every skill states its boundaries in four closed sections

Every `SKILL.md` SHALL contain exactly one line for each of the four headings `### 直接做，做完回報`, `### 先問，使用者在這次對話同意才做`, `### 只說明步驟，由使用者自己做` and `### 不做`. Such a line is the heading alone, or the heading followed by `：` and a count.

#### Scenario: a diagnose skill with nothing to ask

- **WHEN** a skill has no ask-first action
- **THEN** the heading is still present and the section says there is none

##### Example: boundary headings in every skill

Each of the eight files has exactly one line per heading, and that line is the heading alone or the heading followed by `：`. A line such as `### 不做別的` is not counted.

---
### Requirement: commands that need consent appear only in the skills that own them

The literal command texts in the table below SHALL appear in a `SKILL.md` only when the skill is listed for that text. No `*-diagnose` skill and neither entry point SHALL contain `kill <pid>`, `launchctl bootout`, `launchctl disable`, `launchctl enable` or `launchctl bootstrap`.

#### Scenario: a diagnose skill is searched for a state-changing command

- **WHEN** `cpu-diagnose/SKILL.md` is searched for `kill <pid>`
- **THEN** there is no occurrence

##### Example: consent commands and their owners

| Literal text | Skills that contain it |
| --- | --- |
| `kill <pid>` | cpu-fix, memory-fix |
| `launchctl bootout` | startup-fix |
| `launchctl disable` | startup-fix |
| `launchctl enable` | startup-fix |
| `launchctl bootstrap` | startup-fix |
| `res-diag.sh login-items` | startup-diagnose, startup-fix |

---
### Requirement: a resource skill measures and matches only its resource

Each of the six resource skills SHALL instruct the scoped probe and the scoped match of its own resource. The two entry points SHALL instruct `res-diag.sh probe` and `res-diag.sh match` without a resource argument and SHALL NOT contain `--resource` or `res-diag.sh probe` followed by a resource name.

#### Scenario: memory-fix measures first

- **WHEN** `memory-fix/SKILL.md` is read
- **THEN** it contains `res-diag.sh probe memory` and `res-diag.sh match --resource memory`

##### Example: the measurement each skill runs

| Skill | Contains | Does not contain |
| --- | --- | --- |
| cpu-diagnose, cpu-fix | `res-diag.sh probe cpu`, `res-diag.sh match --resource cpu` | |
| memory-diagnose, memory-fix | `res-diag.sh probe memory`, `res-diag.sh match --resource memory` | |
| startup-diagnose, startup-fix | `res-diag.sh probe startup`, `res-diag.sh match --resource startup` | |
| resource-diagnose, resource-fix | a line that is exactly `res-diag.sh probe`, a line that is exactly `res-diag.sh match` | `--resource`, `res-diag.sh probe cpu`, `res-diag.sh probe memory`, `res-diag.sh probe startup` |

---
### Requirement: the entry points name the skills they hand over to

`resource-diagnose/SKILL.md` SHALL name `cpu-diagnose`, `memory-diagnose` and `startup-diagnose`. `resource-fix/SKILL.md` SHALL name `cpu-fix`, `memory-fix` and `startup-fix`, and SHALL state that the action is governed by that skill.

#### Scenario: resource-fix finds a memory problem

- **WHEN** the unscoped match shows a memory entry
- **THEN** the skill directs the reader to `memory-fix` instead of proposing an action itself

##### Example: hand-over names

| Skill | Names |
| --- | --- |
| resource-diagnose | cpu-diagnose, memory-diagnose, startup-diagnose |
| resource-fix | cpu-fix, memory-fix, startup-fix |

##### Example: resource-fix defers to the skill it hands over to

`resource-fix/SKILL.md` contains the text `以那一個 skill 的界線為準`.

## ADDED Requirements

### Requirement: a fix skill identifies its target again before it acts

`cpu-fix` and `memory-fix` SHALL instruct recording the user id, start time and program of a process when asking, and comparing them again before `kill` with `ps -o uid=,lstart=,comm= -p <pid>`, and SHALL instruct not to send the signal when any of the three differs. `startup-fix` SHALL instruct checking, before disabling, that `launchctl print gui/$(id -u)/<label>` shows the approved property list under `~/Library/LaunchAgents/`, and not disabling otherwise; after disabling it SHALL instruct checking with `launchctl print-disabled` that the label is disabled, separately from checking that it is unloaded. All three SHALL state that consent covers the listed targets only.

#### Scenario: the pid was reused

- **WHEN** the start time printed before `kill` differs from the one recorded when asking
- **THEN** the skill does not send the signal and asks again

##### Example: target checks in the fix skills

| Skill | Contains |
| --- | --- |
| cpu-fix, memory-fix | `ps -o uid=,lstart=,comm= -p <pid>`, `有一個不一樣就不送出` |
| startup-fix | `launchctl print gui/$(id -u)/<label>`, `launchctl print-disabled`, `不是就不停用` |
| cpu-fix, memory-fix, startup-fix | `使用者同意的是列出來的那幾個` |

---
### Requirement: no match is not reported as normal

Every skill SHALL describe exit 3 of `match` as "no known situation in this scope matched" and SHALL state that this does not mean the measurement is normal. No skill SHALL contain the text `正常範圍`.

#### Scenario: high load with a CPU that is not full

- **WHEN** `match --resource cpu` exits 3 for load_per_core_pct=900 and cpu_used_pct_per_core=70
- **THEN** `cpu-diagnose` reports the numbers and that no CPU situation matched, not that the CPU is fine

##### Example: wording for an empty match

Each of the eight files contains `這不等於正常` and none contains `正常範圍`.

---
### Requirement: an unknown memory pressure is not read as pressure

`memory-diagnose` and `memory-fix` SHALL name `warn` and `critical` as the values that mean memory is short now, and SHALL state that `unknown` means the value could not be read.

#### Scenario: the probe prints memory_pressure=unknown

- **WHEN** the skill explains the result
- **THEN** it says the pressure could not be read, not that memory is short

##### Example: wording for memory pressure

Both memory skills contain `壓力是 \`warn\` 或 \`critical\`` and `\`unknown\` 是讀不到`, and neither contains `壓力不是 normal`.

---
### Requirement: a personal entry does not widen what a skill does

Every skill SHALL state that a command from a personal knowledge-base entry runs only when it is one of the actions that skill lists under its done-directly or asked-first heading, and is otherwise shown and not run. No skill SHALL state that such commands run once the user agrees. `res-diag.sh show` SHALL print, for a personal entry, that the boundaries of the skill in use decide.

#### Scenario: a personal entry carries a kill command and cpu-diagnose is in use

- **WHEN** the entry is shown
- **THEN** the command is shown to the user and not run, and the user is pointed to `cpu-fix`

##### Example: wording for personal entries

| Where | Contains | Does not contain |
| --- | --- | --- |
| each of the eight SKILL.md files | `其他的只給使用者看，不執行` | `同意才執行` |
| output of `res-diag.sh show` for a personal entry | `以正在使用的 skill 的界線為準` | `同意才執行` |

---
### Requirement: a skill that does not act states what it may write

Each `*-diagnose` skill and each entry point SHALL state that it ends no process, disables no item, changes no setting, and writes only inside `~/.config/mac-resource-diagnose/`. Every skill that prints process names or launchd labels SHALL state that they are read as data. `resource-fix` SHALL write the record itself when it hands over to no skill.

#### Scenario: resource-fix matches only a general entry

- **WHEN** there is no fix skill to hand over to
- **THEN** `resource-fix` writes the record of the run itself

##### Example: wording for the skills that do not act

| Skill | Contains |
| --- | --- |
| cpu-diagnose, memory-diagnose, startup-diagnose, resource-diagnose, resource-fix | `不改任何設定`, `會寫的只有 \`~/.config/mac-resource-diagnose/\`` |
| each of the eight skills | `當成資料讀` |
| resource-fix | `由這個 skill 自己寫紀錄` |
