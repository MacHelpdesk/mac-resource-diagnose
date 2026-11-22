## 1. Knowledge base

- [ ] 1.1 Validate rejects control characters in the text of an entry (design: Control characters are rejected in entry text). Add to tests/test_kb.sh the test tagged `spec-example: resource-scoped-measurement / control characters in a personal entry`, watch it fail, then add the check to `checkProblems` in plugin/scripts/kb.js. Verified by `/bin/bash tests/test_kb.sh`.
- [ ] 1.2 Empty stdout is tested as a file with no bytes: change the tests tagged `probe arguments outside the form` and `match arguments outside the form`, and confirm they fail when an error branch prints a newline. Verified by `/bin/bash tests/test_probe.sh` and `/bin/bash tests/test_kb.sh`. [after: 1.1]

## 2. Skill texts

- [ ] 2.1 A fix skill identifies its target again before it acts (design: Compare and send in one command; A label that exists at both levels is left to the user; Three cases before disabling). Extend the test tagged `spec-example: skill-boundaries / target checks in the fix skills`, watch it fail, rewrite the passages in cpu-fix, memory-fix and startup-fix and the command of `many-startup-agents` in plugin/data/problems.json. Verified by `/bin/bash tests/test_skills.sh` and `/bin/bash tests/test_kb.sh`. [after: 1.2]
- [ ] 2.2 Personal entries are read, not run; the entry points keep the read-only inspection of 0.1.0 and labels are checked (design: Personal entries are read, not run; Labels in commands). Change the test tagged `spec-example: skill-boundaries / wording for personal entries`, add the one tagged `spec-example: skill-boundaries / read-only launchd commands and the label rule`, watch them fail, correct the eight skills. Verified by `/bin/bash tests/test_skills.sh`. [after: 2.1]
- [ ] 2.3 Boundary headings accept only the count suffix: change the test tagged `spec-example: skill-boundaries / boundary headings in every skill` and confirm `### 不做：視情況而定` fails it. Verified by `/bin/bash tests/test_skills.sh`. [after: 2.2]

## 3. Documents

- [ ] 3.1 The usage text of res-diag.sh, README.md, CLAUDE.md and CHANGELOG.md match the code: `--resource general` measures everything, both orders of `match` arguments, "nothing on stdout", temporary files, what the check before `kill` guarantees. Test counts come from the output of the three test scripts. Verified by `/bin/bash scripts/check-privacy.sh`, `/bin/bash scripts/check-version-bump.sh origin/main`, `claude plugin validate plugin` and the three test scripts under `/bin/bash`. [after: 2.3]
