## 1. Script and knowledge base

- [x] 1.1 Label lists every property list that carries a label (design: One subcommand answers "which files carry this label"). Add the fixture folders tests/fixtures/agents_os and tests/fixtures/daemons_os, add to tests/test_probe.sh the test tagged `spec-example: resource-scoped-measurement / label lookups in the fixtures`, watch it fail, then add the `label` subcommand to plugin/scripts/res-diag.sh. Verified by `/bin/bash tests/test_probe.sh`.
- [x] 1.2 A signal that cannot be read is left out: add the test tagged `spec-example: resource-scoped-measurement / a signal that cannot be read is left out`. Verified by `/bin/bash tests/test_probe.sh`. [after: 1.1]
- [x] 1.3 The control-character check is local to entries (design: The control-character check is local to entries). Change the test tagged `spec-example: resource-scoped-measurement / control characters in a personal entry` so that it asserts the entry is absent and the shipped entry present, add the one tagged `spec-example: resource-scoped-measurement / a signal description with a line break still validates`, watch them fail where they do, then move the check into `checkProblems` in plugin/scripts/kb.js. Verified by `/bin/bash tests/test_kb.sh`. [after: 1.2]

## 2. Skill texts

- [x] 2.1 A fix skill identifies its target again before it acts (design: The same check twice, and the same plan; The recorded ps line is what the user is asked about). Extend the test tagged `spec-example: skill-boundaries / target checks in the fix skills`, watch it fail, rewrite the passages in cpu-fix, memory-fix and startup-fix. Verified by `/bin/bash tests/test_skills.sh`. [after: 1.3]
- [x] 2.2 The diagnose skills do not list the commands only a fix needs: add the test tagged `spec-example: skill-boundaries / commands the diagnose skills do not list`, watch it fail, correct the three skills; correct the header comment of tests/test_skills.sh. Verified by `/bin/bash tests/test_skills.sh`. [after: 2.1]

## 3. Real run and documents

- [x] 3.1 Real run on a Mac of `res-diag.sh label` for one user-level label and for one label that does not exist, timing included; output under ~/.config/mac-resource-diagnose/records/ only. README.md, CLAUDE.md, CHANGELOG.md and the verification tables say what was run. Test counts come from the three test scripts. Verified by `/bin/bash scripts/check-privacy.sh`, `/bin/bash scripts/check-version-bump.sh origin/main`, `claude plugin validate plugin` and the three test scripts under `/bin/bash`. [after: 2.2]
