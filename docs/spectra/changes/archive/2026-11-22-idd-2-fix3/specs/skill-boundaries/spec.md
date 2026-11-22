## MODIFIED Requirements

### Requirement: a fix skill identifies its target again before it acts

`cpu-fix` and `memory-fix` SHALL instruct recording the line printed by `ps -o uid=,lstart=,comm= -p <pid>` before asking, SHALL list only a process whose user id equals `id -u`, SHALL require the program of that line to be the program of the measured row and take what the user is asked from that line, SHALL send the signal with one command that compares the line again and runs `kill <pid>` only when it is unchanged, and SHALL state that this comparison is best effort and not a guarantee.

`startup-fix` SHALL instruct running `res-diag.sh label <label>` and `launchctl print gui/$(id -u)/<label>` when asking and again before acting. It SHALL act only when the label check prints exactly one line, of source `user-agent`, with the approved property list; when another line is printed it SHALL leave the item to the user. From `launchctl print` it SHALL tell three cases: loaded from the approved property list (`launchctl bootout`, and `launchctl disable` only after that succeeded), not loaded (`launchctl disable` alone), loaded from elsewhere or unreadable (no action). It SHALL tell the user how many commands will run and SHALL ask again when the second check gives a different result. After disabling it SHALL instruct checking with `launchctl print-disabled` that the label is disabled, separately from checking that it is unloaded, and reporting a failed query as not confirmed. All three skills SHALL state that consent covers the listed targets only.

#### Scenario: the pid was reused

- **WHEN** the line printed before `kill` differs from the one recorded when asking
- **THEN** the command does not send the signal and the skill asks again

#### Scenario: the property list changed after the user agreed

- **WHEN** the second label check no longer prints the approved file
- **THEN** `startup-fix` does not act and asks again

##### Example: target checks in the fix skills

| Skill | Contains |
| --- | --- |
| cpu-fix, memory-fix | `ps -o uid=,lstart=,comm= -p <pid>`, `&& kill <pid>`, `id -u`, `不列進去問`, `問的內容以這一行為準`, `盡力核對，不是保證`, `有一個不一樣就不送出` |
| startup-fix | `res-diag.sh label <label>`, `launchctl print gui/$(id -u)/<label>`, `launchctl print-disabled`, `系統層有同名的項目就不代為停用`, `沒有載入的項目只做`, `不是就不停用`, `和問的時候不一樣就重新問`, `無法確認` |
| cpu-fix, memory-fix, startup-fix | `使用者同意的是列出來的那幾個` |

---
### Requirement: a skill that does not act states what it may write

Each `*-diagnose` skill and each entry point SHALL state that it ends no process, disables no item, changes no setting, and writes only inside `~/.config/mac-resource-diagnose/`. Every skill that prints process names or launchd labels SHALL state that they are read as data. `resource-fix` SHALL write the record itself when it hands over to no skill. A `*-diagnose` skill SHALL NOT list the commands that only a fix needs: `id -u` in `cpu-diagnose` and `memory-diagnose`, `launchctl print-disabled` in `startup-diagnose`.

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
| startup-diagnose | `launchctl print-disabled` |
