#!/bin/bash
# test_skills — the eight skills exist, each states its boundaries, and a command that
# needs the user's consent is written only in the skills that own it.
#
# These are checks on text. They look for the command strings and sentences that the
# spec lists, and for where each may appear. They do not show that a skill is free of
# every state-changing command, nor what a model does after reading the skill.

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
# the direct subdirectories, hidden ones included: ls would not show a hidden one
eq "skill directories" "$ALL " "$(find "$SK" -mindepth 1 -maxdepth 1 -type d | sed 's|.*/||' | sort | tr '\n' ' ')"
for s in $ALL; do
  eq "$s: frontmatter name" "$s" "$(front "$s" name)"
  [ -n "$(front "$s" description)" ] && ok || bad "$s: description is empty"
done

# spec-example: skill-boundaries / boundary headings in every skill
for s in $ALL; do
  for h in '### 直接做，做完回報' '### 先問，使用者在這次對話同意才做' '### 只說明步驟，由使用者自己做' '### 不做'; do
    # the heading alone, or the heading followed by "：只有這<count>件"
    eq "$s: heading \"$h\"" "1" "$(grep -cxE -- "$h(：只有這[一二兩三四五六七八九十]+件)?" "$SK/$s/SKILL.md" 2>/dev/null)"
    eq "$s: nothing else starts with \"$h\"" "1" "$(grep -c -- "^$h" "$SK/$s/SKILL.md" 2>/dev/null)"
  done
done

# spec-example: skill-boundaries / consent commands and their owners
eq "owners of kill <pid>" "cpu-fix memory-fix " "$(owners 'kill <pid>')"
eq "owners of launchctl bootout" "startup-fix " "$(owners 'launchctl bootout')"
eq "owners of launchctl disable" "startup-fix " "$(owners 'launchctl disable')"
eq "owners of launchctl enable" "startup-fix " "$(owners 'launchctl enable')"
eq "owners of launchctl bootstrap" "startup-fix " "$(owners 'launchctl bootstrap')"
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
  grep -qxF 'res-diag.sh probe' "$SK/$s/SKILL.md" && ok || bad "$s has no line that is exactly res-diag.sh probe"
  grep -qxF 'res-diag.sh match' "$SK/$s/SKILL.md" && ok || bad "$s has no line that is exactly res-diag.sh match"
  hasnt "$s" "--resource"
  for r in cpu memory startup; do hasnt "$s" "res-diag.sh probe $r"; done
done

# spec-example: skill-boundaries / hand-over names
for r in cpu memory startup; do
  has resource-diagnose "$r-diagnose"
  has resource-fix "$r-fix"
done

# spec-example: skill-boundaries / resource-fix defers to the skill it hands over to
has resource-fix '以那一個 skill 的界線為準'

# spec-example: skill-boundaries / target checks in the fix skills
for s in cpu-fix memory-fix; do
  has "$s" 'ps -o uid=,lstart=,comm= -p <pid>'
  has "$s" '&& kill <pid>'
  has "$s" 'id -u'
  has "$s" '盡力核對，不是保證'
  has "$s" '不列進去問'
  has "$s" 'ps -o pcpu=,rss= -p <pid>'
  has "$s" '第一行與第三行要一樣'
  has "$s" '問的內容都取自這次讀取'
  has "$s" '有一個不一樣就不送出'
done
has startup-fix 'launchctl print gui/$(id -u)/<label>'
has startup-fix 'launchctl print-disabled'
has startup-fix '不是就不停用'
has startup-fix '系統層有同名的項目就不代為停用'
has startup-fix '沒有載入的項目只做'
has startup-fix '無法確認'
has startup-fix 'res-diag.sh label <label>'
has startup-fix '和問的時候不一樣就重新問'
has startup-fix '結束碼不是 0 就不做'
has startup-fix 'cksum'
for s in cpu-fix memory-fix startup-fix; do has "$s" '使用者同意的是列出來的那幾個'; done

# spec-example: skill-boundaries / wording for an empty match
for s in $ALL; do
  has "$s" '這不等於正常'
  hasnt "$s" '正常範圍'
done

# spec-example: skill-boundaries / wording for memory pressure
for s in memory-diagnose memory-fix; do
  has "$s" '壓力是 `warn` 或 `critical`'
  has "$s" '`unknown` 是讀不到'
  hasnt "$s" '壓力不是 normal'
done

# spec-example: skill-boundaries / wording for personal entries
for s in $ALL; do
  has "$s" '不照條目裡的字串執行'
  hasnt "$s" '同意才執行'
done

# spec-example: skill-boundaries / wording for the skills that do not act
for s in cpu-diagnose memory-diagnose startup-diagnose resource-diagnose resource-fix; do
  has "$s" '不改任何設定'
  has "$s" '會寫的只有 `~/.config/mac-resource-diagnose/`'
done
for s in $ALL; do has "$s" '當成資料讀'; done
has resource-fix '由這個 skill 自己寫紀錄'

# spec-example: skill-boundaries / commands the diagnose skills do not list
hasnt cpu-diagnose 'id -u'
hasnt memory-diagnose 'id -u'
hasnt startup-diagnose 'launchctl print-disabled'
hasnt startup-diagnose 'cksum'
hasnt startup-diagnose 'res-diag.sh label'
# `label` is also a column of the startup listing, so only the done-directly row is searched
grep '^| 1 |' "$SK/startup-diagnose/SKILL.md" | grep -qF '`label`' && bad "startup-diagnose lists the label subcommand as done directly" || ok
grep '^| 1 |' "$SK/startup-fix/SKILL.md" | grep -qF '`label`' && ok || bad "startup-fix does not list the label subcommand as done directly"

# spec-example: skill-boundaries / read-only launchd commands and the label rule
for s in resource-diagnose resource-fix startup-diagnose startup-fix; do
  has "$s" 'launchctl print gui/<uid>/<label>'
  has "$s" 'plutil -p <plist>'
  has "$s" '才代入指令'
done

# No skill carries a command the knowledge base lists under "never".
for s in $ALL; do
  hasnt "$s" 'kill -9 <'
  hasnt "$s" 'sudo launchctl'
done

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
