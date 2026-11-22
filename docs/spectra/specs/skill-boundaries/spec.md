# skill-boundaries Specification

## Purpose

The plugin's skills are split by resource and by action. This capability fixes which skills exist, which of them may propose a command that changes the state of the Mac, and what the two entry points hand over, so that a skill named `*-diagnose` can be trusted to change nothing.

## Requirements

### Requirement: the plugin ships eight skills

`plugin/skills/` SHALL hold exactly eight directories, each with a `SKILL.md` whose frontmatter `name` equals the directory name: `resource-diagnose`, `resource-fix`, `cpu-diagnose`, `cpu-fix`, `memory-diagnose`, `memory-fix`, `startup-diagnose`, `startup-fix`.

#### Scenario: listing the skills

- **WHEN** the directories under `plugin/skills/` are listed
- **THEN** they are the eight names and each frontmatter name matches

##### Example: the eight skill names

cpu-diagnose, cpu-fix, memory-diagnose, memory-fix, resource-diagnose, resource-fix, startup-diagnose, startup-fix: eight directories, eight matching `name` fields, each with a non-empty `description`.

---
### Requirement: every skill states its boundaries in four closed sections

Every `SKILL.md` SHALL contain the four headings `### 直接做，做完回報`, `### 先問，使用者在這次對話同意才做`, `### 只說明步驟，由使用者自己做` and `### 不做`, each once.

#### Scenario: a diagnose skill with nothing to ask

- **WHEN** a skill has no ask-first action
- **THEN** the heading is still present and the section says there is none

##### Example: boundary headings in every skill

Each of the eight files contains each of the four headings exactly once.

---
### Requirement: commands that need consent appear only in the skills that own them

The literal command texts in the table below SHALL appear in a `SKILL.md` only when the skill is listed for that text. No `*-diagnose` skill and neither entry point SHALL contain `kill <pid>`, `launchctl bootout` or `launchctl disable`.

#### Scenario: a diagnose skill is searched for a state-changing command

- **WHEN** `cpu-diagnose/SKILL.md` is searched for `kill <pid>`
- **THEN** there is no occurrence

##### Example: consent commands and their owners

| Literal text | Skills that contain it |
| --- | --- |
| `kill <pid>` | cpu-fix, memory-fix |
| `launchctl bootout` | startup-fix |
| `launchctl disable` | startup-fix |
| `res-diag.sh login-items` | startup-diagnose, startup-fix |

---
### Requirement: a resource skill measures and matches only its resource

Each of the six resource skills SHALL instruct the scoped probe and the scoped match of its own resource. The two entry points SHALL instruct the unscoped `res-diag.sh probe` and `res-diag.sh match` and SHALL NOT contain `--resource`.

#### Scenario: memory-fix measures first

- **WHEN** `memory-fix/SKILL.md` is read
- **THEN** it contains `res-diag.sh probe memory` and `res-diag.sh match --resource memory`

##### Example: the measurement each skill runs

| Skill | Contains | Does not contain |
| --- | --- | --- |
| cpu-diagnose, cpu-fix | `res-diag.sh probe cpu`, `res-diag.sh match --resource cpu` | |
| memory-diagnose, memory-fix | `res-diag.sh probe memory`, `res-diag.sh match --resource memory` | |
| startup-diagnose, startup-fix | `res-diag.sh probe startup`, `res-diag.sh match --resource startup` | |
| resource-diagnose, resource-fix | `res-diag.sh probe`, `res-diag.sh match` | `--resource` |

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
