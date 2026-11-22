## MODIFIED Requirements

### Requirement: every skill states its boundaries in four closed sections

Every `SKILL.md` SHALL contain exactly one line for each of the four headings `### 直接做，做完回報`, `### 先問，使用者在這次對話同意才做`, `### 只說明步驟，由使用者自己做` and `### 不做`. Such a line is the heading alone, or the heading followed by `：只有這`, a count written in Chinese numerals and `件`.

#### Scenario: a diagnose skill with nothing to ask

- **WHEN** a skill has no ask-first action
- **THEN** the heading is still present and the section says there is none

##### Example: boundary headings in every skill

Each of the eight files has exactly one line per heading in one of the two forms, for example `### 不做` or `### 直接做，做完回報：只有這四件`, and no other line that starts with a heading. `### 不做別的` and `### 不做：視情況而定` are not counted.

---
### Requirement: a fix skill identifies its target again before it acts

`cpu-fix` and `memory-fix` SHALL instruct recording the line printed by `ps -o uid=,lstart=,comm= -p <pid>` when asking, SHALL list only a process whose user id equals `id -u`, SHALL send the signal with one command that compares that line again and runs `kill <pid>` only when it is unchanged, and SHALL state that this comparison is best effort and not a guarantee. `startup-fix` SHALL instruct, before disabling: not to act when the same label appears under `system-agent` or `system-daemon`; to check with `launchctl print gui/$(id -u)/<label>` whether the service is loaded from the approved property list under `~/Library/LaunchAgents/`, is not loaded, or is loaded from elsewhere; to run `launchctl disable` only after a successful `launchctl bootout` or, for an item that is not loaded, alone; and not to act when it is loaded from elsewhere. After disabling it SHALL instruct checking with `launchctl print-disabled` that the label is disabled, separately from checking that it is unloaded, and reporting a failed query as not confirmed. All three SHALL state that consent covers the listed targets only.

#### Scenario: the pid was reused

- **WHEN** the line printed before `kill` differs from the one recorded when asking
- **THEN** the command does not send the signal and the skill asks again

##### Example: target checks in the fix skills

| Skill | Contains |
| --- | --- |
| cpu-fix, memory-fix | `ps -o uid=,lstart=,comm= -p <pid>`, `&& kill <pid>`, `id -u`, `盡力核對，不是保證`, `有一個不一樣就不送出` |
| startup-fix | `launchctl print gui/$(id -u)/<label>`, `launchctl print-disabled`, `系統層有同名的項目就不代為停用`, `沒有載入的項目只做`, `不是就不停用`, `無法確認` |
| cpu-fix, memory-fix, startup-fix | `使用者同意的是列出來的那幾個` |

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

## ADDED Requirements

### Requirement: the entry points keep the read-only inspection of 0.1.0, and labels are checked before they enter a command

`resource-diagnose` and `resource-fix` SHALL list `launchctl print gui/<uid>/<label>` and `plutil -p <plist>` among the commands they run directly. Every skill that lists `launchctl print gui/<uid>/<label>` SHALL state that a label is put into a command only when it consists of letters, digits, `.`, `-` and `_`.

#### Scenario: a label with a space

- **WHEN** a property list carries a label that contains a space
- **THEN** the skill does not put it into a command and tells the user

##### Example: read-only launchd commands and the label rule

| Skill | Contains |
| --- | --- |
| resource-diagnose, resource-fix, startup-diagnose, startup-fix | `launchctl print gui/<uid>/<label>`, `plutil -p <plist>`, `才代入指令` |
