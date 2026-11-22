## Why

Version 0.1.0 has one skill, `resource-diagnose`, that measures, interprets and acts in a single flow, and one `probe` that always measures everything. The maintainer decided (issue #1) to split by resource and by action: someone who already knows the CPU is the problem should be able to call `cpu-fix` directly, and a skill whose name ends in `-diagnose` should never change anything. Issue #2 is the first of four parts and covers the three resources 0.1.0 already measures.

## What Changes

- The plugin ships eight skills instead of one: `resource-diagnose` and `resource-fix` (entry points for "the Mac is slow" when the resource is not known), and `cpu-diagnose`, `cpu-fix`, `memory-diagnose`, `memory-fix`, `startup-diagnose`, `startup-fix`.
- **BREAKING**: `resource-diagnose` no longer ends a process or disables a startup item. Those actions move to `cpu-fix`, `memory-fix` and `startup-fix`.
- `res-diag.sh probe` accepts one resource (`cpu`, `memory`, `startup`) and then prints only that resource's signals. Without an argument its output is unchanged.
- Every signal and every knowledge-base entry carries a `resource`. `res-diag.sh match --resource R` compares only entries of that resource. The entry `load-above-cpu` is `general`: its cause can lie outside the CPU, so only the entry points use it.
- `res-diag.sh show ID` prints the entry's resource.
- A personal entry without `resource` keeps validating and counts as `general`.
- Version becomes 0.2.0.

## Capabilities

### New Capabilities

- `resource-scoped-measurement`: which signals and knowledge-base entries belong to which resource, and how `probe`, `match`, `show` and `validate` use that.
- `skill-boundaries`: the eight skills, which of them may propose a state-changing command, and what the two entry points hand over.

### Modified Capabilities

(none)

## Impact

- Changed files: plugin/scripts/res-diag.sh, plugin/scripts/kb.js, plugin/data/problems.json, plugin/skills/resource-diagnose/SKILL.md, plugin/.claude-plugin/plugin.json, tests/test_probe.sh, tests/test_kb.sh, README.md, CLAUDE.md, CHANGELOG.md.
- New files: seven SKILL.md files under plugin/skills/, tests/test_skills.sh.
- Installers of 0.1.0: `resource-diagnose` stops acting; `resource-fix` or one of the `*-fix` skills takes over that part.
- The marketplace index in MacHelpdesk/mac-helpdesk copies the manifest description and is updated separately after this merges (MacHelpdesk/mac-helpdesk#12).
