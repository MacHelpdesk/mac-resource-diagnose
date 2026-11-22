## ADDED Requirements

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
