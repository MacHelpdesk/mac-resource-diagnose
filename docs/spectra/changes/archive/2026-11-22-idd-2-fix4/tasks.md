## 1. Script

- [x] 1.1 Label parses every property list and reports an incomplete lookup (design: Parse, then compare; Incomplete is an exit status). Add the fixtures (a label written with a character reference, a folder with a broken file and a dangling link), add to tests/test_probe.sh the tests tagged `spec-example: resource-scoped-measurement / a label written with a character reference is found` and `spec-example: resource-scoped-measurement / an unreadable property list makes the lookup incomplete`, watch them fail, then add plugin/scripts/labels.js and call it from `label` in plugin/scripts/res-diag.sh. Verified by `/bin/bash tests/test_probe.sh`.
- [x] 1.2 An unreadable memory pressure is printed as unknown: add the test tagged `spec-example: resource-scoped-measurement / an unreadable memory pressure is printed as unknown`. Verified by `/bin/bash tests/test_probe.sh`. [after: 1.1]
- [x] 1.3 The message for a control character names it: change `checkProblems` in plugin/scripts/kb.js and check the message in tests/test_kb.sh. Verified by `/bin/bash tests/test_kb.sh`. [after: 1.2]

## 2. Skill texts

- [x] 2.1 A fix skill identifies its target again before it acts (design: The checksum of the property list is part of what was approved; One reading for a process). Extend the test tagged `spec-example: skill-boundaries / target checks in the fix skills`, watch it fail, rewrite the passages in cpu-fix, memory-fix and startup-fix. Verified by `/bin/bash tests/test_skills.sh`. [after: 1.3]
- [x] 2.2 The diagnose skills do not list the commands only a fix needs; the eight directories are counted with hidden ones: extend the tests tagged `spec-example: skill-boundaries / commands the diagnose skills do not list` and `spec-example: skill-boundaries / the eight skill names`, watch them fail where they do, correct startup-diagnose. Verified by `/bin/bash tests/test_skills.sh`. [after: 2.1]

## 3. Real run and documents

- [x] 3.1 Real run on a Mac of the new `label`, of `cksum` on a property list and of the three-line process reading; output under ~/.config/mac-resource-diagnose/records/ only. README.md, CLAUDE.md, CHANGELOG.md and the verification tables say what was run; test counts come from the three test scripts. Verified by `/bin/bash scripts/check-privacy.sh`, `/bin/bash scripts/check-version-bump.sh origin/main`, `claude plugin validate plugin` and the three test scripts under `/bin/bash`. [after: 2.2]
