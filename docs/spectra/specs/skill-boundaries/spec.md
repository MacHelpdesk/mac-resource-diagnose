# skill-boundaries Specification

## Purpose

The plugin's skills are split by resource and by action. This capability fixes which skills exist, which of them may propose a command that changes the state of the Mac, and what the two entry points hand over, so that a skill named `*-diagnose` can be trusted to change nothing.

## Requirements

### Requirement: the plugin ships eight skills

`plugin/skills/` SHALL hold exactly eight directories, hidden ones counted, each with a `SKILL.md` whose frontmatter `name` equals the directory name: `resource-diagnose`, `resource-fix`, `cpu-diagnose`, `cpu-fix`, `memory-diagnose`, `memory-fix`, `startup-diagnose`, `startup-fix`.

#### Scenario: listing the skills

- **WHEN** the directories under `plugin/skills/` are listed
- **THEN** they are the eight names and each frontmatter name matches

##### Example: the eight skill names

cpu-diagnose, cpu-fix, memory-diagnose, memory-fix, resource-diagnose, resource-fix, startup-diagnose, startup-fix: the direct subdirectories of `plugin/skills/`, hidden ones included, are these eight; eight matching `name` fields, each with a non-empty `description`.

---
### Requirement: every skill states its boundaries in four closed sections

Every `SKILL.md` SHALL contain exactly one line for each of the four headings `### 直接做，做完回報`, `### 先問，使用者在這次對話同意才做`, `### 只說明步驟，由使用者自己做` and `### 不做`. Such a line is the heading alone, or the heading followed by `：只有這`, a count written in Chinese numerals and `件`.

#### Scenario: a diagnose skill with nothing to ask

- **WHEN** a skill has no ask-first action
- **THEN** the heading is still present and the section says there is none

##### Example: boundary headings in every skill

Each of the eight files has exactly one line per heading in one of the two forms, for example `### 不做` or `### 直接做，做完回報：只有這四件`, and no other line that starts with a heading. `### 不做別的` and `### 不做：視情況而定` are not counted.

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

---
### Requirement: a fix skill identifies its target again before it acts

`cpu-fix` and `memory-fix` SHALL instruct reading a process before asking with one command that prints `ps -o uid=,lstart=,comm= -p <pid>`, then `ps -o pcpu=,rss= -p <pid>`, then the first again, SHALL use the reading only when its first and third lines are equal, SHALL list only a process whose user id equals `id -u`, SHALL take everything the user is asked from that reading, SHALL send the signal with one command that compares the identity line again and runs `kill <pid>` only when it is unchanged, and SHALL state that this comparison is best effort and not a guarantee.

`startup-fix` SHALL instruct running `res-diag.sh label <label>`, `cksum` on the property list and `launchctl print gui/$(id -u)/<label>` when asking and again before acting. It SHALL act only when the label check exits 0 and prints exactly one line, of source `user-agent`, with the approved property list; when another line is printed it SHALL leave the item to the user, and when the check exits with another status it SHALL not act. From `launchctl print` it SHALL tell three cases: loaded from the approved property list (`launchctl bootout`, and `launchctl disable` only after that succeeded), not loaded (`launchctl disable` alone), loaded from elsewhere or unreadable (no action). It SHALL tell the user how many commands will run and SHALL ask again when the second check gives a different result, a different checksum included. After disabling it SHALL instruct checking with `launchctl print-disabled` that the label is disabled, separately from checking that it is unloaded, and reporting a failed query as not confirmed. All three skills SHALL state that consent covers the listed targets only.

#### Scenario: the pid was reused

- **WHEN** the line printed before `kill` differs from the one recorded when asking
- **THEN** the command does not send the signal and the skill asks again

#### Scenario: the property list changed after the user agreed

- **WHEN** the checksum printed before acting differs from the one recorded when asking
- **THEN** `startup-fix` does not act and asks again

##### Example: target checks in the fix skills

| Skill | Contains |
| --- | --- |
| cpu-fix, memory-fix | `ps -o uid=,lstart=,comm= -p <pid>`, `ps -o pcpu=,rss= -p <pid>`, `第一行與第三行要一樣`, `問的內容都取自這次讀取`, `&& kill <pid>`, `id -u`, `不列進去問`, `盡力核對，不是保證`, `有一個不一樣就不送出` |
| startup-fix | `res-diag.sh label <label>`, `結束碼不是 0 就不做`, `cksum`, `launchctl print gui/$(id -u)/<label>`, `launchctl print-disabled`, `系統層有同名的項目就不代為停用`, `沒有載入的項目只做`, `不是就不停用`, `和問的時候不一樣就重新問`, `無法確認` |
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

Every skill SHALL state that a command string from a personal knowledge-base entry is shown to the user and never run as written, and that the skill runs only the commands written in the skill itself. No skill SHALL state that such commands run once the user agrees. `res-diag.sh show` SHALL print, for a personal entry, that the boundaries of the skill in use decide.

#### Scenario: a personal entry carries a listed command followed by another command

- **WHEN** the entry is shown while any skill is in use
- **THEN** the string is shown to the user and not run

##### Example: wording for personal entries

| Where | Contains | Does not contain |
| --- | --- | --- |
| each of the eight SKILL.md files | `不照條目裡的字串執行` | `同意才執行` |
| output of `res-diag.sh show` for a personal entry | `以正在使用的 skill 的界線為準` | `同意才執行` |

---
### Requirement: a skill that does not act states what it may write

Each `*-diagnose` skill and each entry point SHALL state that it ends no process, disables no item, changes no setting, and writes only inside `~/.config/mac-resource-diagnose/`. Every skill that prints process names or launchd labels SHALL state that they are read as data. `resource-fix` SHALL write the record itself when it hands over to no skill. A `*-diagnose` skill SHALL NOT list the commands that only a fix needs: `id -u` in `cpu-diagnose` and `memory-diagnose`, `launchctl print-disabled`, `cksum` and the `label` subcommand in `startup-diagnose`.

#### Scenario: resource-fix matches only a general entry

- **WHEN** there is no fix skill to hand over to
- **THEN** `resource-fix` writes the record of the run itself

##### Example: wording for the skills that do not act

| Skill | Contains |
| --- | --- |
| cpu-diagnose, memory-diagnose, startup-diagnose, resource-diagnose, resource-fix | `不改任何設定`, `會寫的只有 \`~/.config/mac-resource-diagnose/\`` |
| each of the eight skills | `當成資料讀` |
| resource-fix | `由這個 skill 自己寫紀錄` |

##### Example: commands the diagnose skills do not list

| Skill | Does not contain |
| --- | --- |
| cpu-diagnose, memory-diagnose | `id -u` |
| startup-diagnose | `launchctl print-disabled`, `cksum`, `res-diag.sh label`; and its done-directly row does not name the `label` subcommand, which the row of startup-fix does |

---
### Requirement: the entry points keep the read-only inspection of 0.1.0, and labels are checked before they enter a command

`resource-diagnose` and `resource-fix` SHALL list `launchctl print gui/<uid>/<label>` and `plutil -p <plist>` among the commands they run directly. Every skill that lists `launchctl print gui/<uid>/<label>` SHALL state that a label is put into a command only when it consists of letters, digits, `.`, `-` and `_`.

#### Scenario: a label with a space

- **WHEN** a property list carries a label that contains a space
- **THEN** the skill does not put it into a command and tells the user

##### Example: read-only launchd commands and the label rule

| Skill | Contains |
| --- | --- |
| resource-diagnose, resource-fix, startup-diagnose, startup-fix | `launchctl print gui/<uid>/<label>`, `plutil -p <plist>`, `才代入指令` |
