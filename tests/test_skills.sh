#!/bin/bash
# test_skills — the eight skills exist, each states its boundaries, and a command that
# needs the user's consent is written only in the skills that own it.
#
# These are checks on text. They show that a skill named *-diagnose does not contain a
# state-changing command; they cannot show what a model does after reading the skill.

set -u
cd "$(dirname "$0")/.." || exit 2
SK=plugin/skills
ALL="cpu-diagnose cpu-fix memory-diagnose memory-fix resource-diagnose resource-fix startup-diagnose startup-fix"

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
eq()  { [ "$2" = "$3" ] && ok || bad "$1: expected [$2] got [$3]"; }

# front SKILL KEY: the value of a one-line frontmatter key
front() { awk -v k="$2" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } index($0, k ": ") == 1 { print substr($0, length(k) + 3) }' "$SK/$1/SKILL.md" 2>/dev/null; }
# owners TEXT: the skills whose SKILL.md contains TEXT, in ALL order
owners() { local s o=""; for s in $ALL; do grep -qF -- "$1" "$SK/$s/SKILL.md" 2>/dev/null && o="$o$s "; done; printf '%s' "$o"; }
has()    { grep -qF -- "$2" "$SK/$1/SKILL.md" 2>/dev/null && ok || bad "$1 does not contain \"$2\""; }
hasnt()  { grep -qF -- "$2" "$SK/$1/SKILL.md" 2>/dev/null && bad "$1 contains \"$2\"" || ok; }

# spec-example: skill-boundaries / the eight skill names
eq "skill directories" "$ALL " "$(ls "$SK" | sort | tr '\n' ' ')"
for s in $ALL; do
  eq "$s: frontmatter name" "$s" "$(front "$s" name)"
  [ -n "$(front "$s" description)" ] && ok || bad "$s: description is empty"
done

# spec-example: skill-boundaries / boundary headings in every skill
for s in $ALL; do
  for h in '### 直接做，做完回報' '### 先問，使用者在這次對話同意才做' '### 只說明步驟，由使用者自己做' '### 不做'; do
    eq "$s: heading \"$h\"" "1" "$(grep -c -- "^$h" "$SK/$s/SKILL.md" 2>/dev/null)"
  done
done

# spec-example: skill-boundaries / consent commands and their owners
eq "owners of kill <pid>" "cpu-fix memory-fix " "$(owners 'kill <pid>')"
eq "owners of launchctl bootout" "startup-fix " "$(owners 'launchctl bootout')"
eq "owners of launchctl disable" "startup-fix " "$(owners 'launchctl disable')"
eq "owners of res-diag.sh login-items" "startup-diagnose startup-fix " "$(owners 'res-diag.sh login-items')"
# The same action is asked about in the same words wherever it is repeated.
row() { grep -F -- "$2" "$SK/$1/SKILL.md" 2>/dev/null | grep '^| 1 |\|^| 2 |' | sed 's/^| [0-9] |//'; }
eq "the kill row is the same in cpu-fix and memory-fix" "$(row cpu-fix 'kill <pid>')" "$(row memory-fix 'kill <pid>')"
eq "the login-items row is the same in startup-diagnose and startup-fix" "$(row startup-diagnose 'res-diag.sh login-items')" "$(row startup-fix 'res-diag.sh login-items')"
[ -n "$(row cpu-fix 'kill <pid>')" ] && ok || bad "cpu-fix has no table row for kill <pid>"
[ -n "$(row startup-fix 'res-diag.sh login-items')" ] && ok || bad "startup-fix has no table row for login-items"

# spec-example: skill-boundaries / the measurement each skill runs
for r in cpu memory startup; do
  for s in "$r-diagnose" "$r-fix"; do
    has "$s" "res-diag.sh probe $r"
    has "$s" "res-diag.sh match --resource $r"
  done
done
for s in resource-diagnose resource-fix; do
  has "$s" "res-diag.sh probe"
  has "$s" "res-diag.sh match"
  hasnt "$s" "--resource"
done

# spec-example: skill-boundaries / hand-over names
for r in cpu memory startup; do
  has resource-diagnose "$r-diagnose"
  has resource-fix "$r-fix"
done

# No skill carries a command the knowledge base lists under "never".
for s in $ALL; do
  hasnt "$s" 'kill -9 <'
  hasnt "$s" 'sudo launchctl'
done

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
