## Context

`res-diag.sh` is a read-only bash 3.2 script; the knowledge base is read through JXA in `kb.js`. The single skill holds four closed boundary tables: done directly, asked first, explained only, never. Three more parts follow this one (GPU, disk I/O, power; issues #3 to #5) and each will add a resource the same way, so the shape chosen here is the shape they inherit.

The maintainer left the form of the fix skills to the diagnosis (issue #1, Clarity Surface row 3) and stated in issue #2 that a `*-fix` skill measures first by itself.

## Goals / Non-Goals

**Goals:**

- A resource can be measured and matched on its own.
- A skill named `*-diagnose` contains no command that changes the state of the Mac.
- Each state-changing command is written in exactly the skills that own it, and a test fails when it appears elsewhere.
- Calls that worked in 0.1.0 (`probe`, `match [FILE]`, a personal entry without `resource`) keep working with the same output.

**Non-Goals:**

- No new measurement. GPU, disk I/O, battery and temperature belong to issues #3 to #5.
- No new action. The three ask-first actions of 0.1.0 are moved, not extended.
- No hook. Whether the model picks the right one of eight skills is observed in use, not enforced here.
- The marketplace index (another repository).

## Decisions

### A resource is a field on signals and on entries

`problems.json` gains `resource` on each of the 14 signals (`cpu`, `memory` or `startup`) and on each entry (those three or `general`). The alternative, one knowledge-base file per resource, would split the `signals` and `never` lists that every entry shares and would make the entry points read several files.

### An entry of one resource may only use that resource's signals

`validate` rejects an entry tagged `cpu`, `memory` or `startup` whose conditions name a signal of another resource. Without this rule `match --resource cpu` on a CPU-only probe could contain an entry that can never match, and nobody would notice. `general` entries may use any signal.

### The entry points carry no state-changing command

`resource-diagnose` measures and matches everything and names the resource. `resource-fix` does the same and then hands over to `cpu-fix`, `memory-fix` or `startup-fix`, whose tables govern the action. The alternative, repeating the `kill` and `launchctl` rows in `resource-fix`, gives two copies that can drift apart; a single owner per row is what the skill test checks.

### "Changes nothing" means the state of the Mac

A `*-diagnose` skill ends no process, unloads no service, changes no setting and touches no file outside `~/.config/mac-resource-diagnose/`. It may still write the record of the run and a personal knowledge-base entry there. `res-diag.sh login-items` stays ask-first even though it only reads, because macOS may show a permission prompt; it is carried by `startup-diagnose` and `startup-fix` only.

### `probe RESOURCE` is positional and `match` takes `--resource`

`probe` had no argument, so a positional resource is unambiguous. `match` already takes an optional signals file as its first argument, so the resource is a named option that can stand before or after the file. `match --resource R` without a file probes only R.

### A missing `resource` on an entry is `general`

Personal files written for 0.1.0 have no such field. Treating it as `general` keeps them valid, and they keep appearing in the unscoped `match`. The shipped file is held to the stricter rule by a test: every shipped entry names its resource.

### Usage text is found by marker, not by line number

`res-diag.sh` prints its header as usage with `sed -n '2,22p'`. The header grows in this change, so the usage text ends at the first empty line instead.

## Implementation Contract

- `res-diag.sh probe [cpu|memory|startup]`: exit 0; an unknown resource prints nothing on stdout and exits 64.
- `res-diag.sh match [--resource cpu|memory|startup|general] [SIGNALS_FILE]`: output columns unchanged (id, evidence status, origin, title); exit 3 when nothing matches; an unknown resource exits 64.
- `res-diag.sh show ID`: adds one line `resource: <value>`.
- `kb.js validate`: `signals.<name>.resource` is required and one of `cpu`, `memory`, `startup`; `problems[].resource` is optional and one of those three or `general`.
- Each SKILL.md has the four headings `### 直接做，做完回報`, `### 先問，使用者在這次對話同意才做`, `### 只說明步驟，由使用者自己做`, `### 不做`.
- Tests read only tests/fixtures and the files under plugin/.

## Risks / Trade-offs

- Eight descriptions compete in the skill listing, where Claude Code may drop descriptions (seen in mac-dropbox-fix issue #9). Descriptions are kept short and each names its resource first. No hook is added in this part.
- `resource-fix` measures, then the resource's fix skill measures again. The second probe is scoped to one resource and is cheaper; the repetition buys a single owner for each action.
- The `kill` and `launchctl` actions stay unverified: nothing in this change runs them.
