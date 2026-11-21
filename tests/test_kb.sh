#!/bin/bash
# test_kb — the knowledge base validates, and signals match the situations they should.

set -u
cd "$(dirname "$0")/.." || exit 2
TOOL=plugin/scripts/res-diag.sh
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export RES_DIAG_LOCAL_KB="$TMPD/none.json"

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
eq()  { [ "$2" = "$3" ] && ok || bad "$1: expected [$2] got [$3]"; }

ids() { cut -f1 | sort | tr '\n' ' '; }
sig() { printf '%s\n' "$@" > "$TMPD/s"; /bin/bash "$TOOL" match "$TMPD/s" | ids; }

/bin/bash "$TOOL" validate >/dev/null 2>&1 && ok || bad "shipped knowledge base does not validate"

n="$(/bin/bash "$TOOL" list | awk -F'\t' 'NF==4 && $3=="shipped"' | wc -l | tr -d ' ')"
eq "list: seven well-formed shipped lines" "7" "$n"

eq "one busy process" "single-process-busy " \
  "$(sig top_process_cpu_pct=185 busy_group_size=1 load_per_core_pct=60 cpu_used_pct_per_core=50 memory_pressure=normal swap_used_mb=0 startup_user_agents=2 running_third_party_services=3)"
eq "many copies of one job" "many-parallel-jobs " \
  "$(sig top_process_cpu_pct=60 busy_group_size=5 load_per_core_pct=180 cpu_used_pct_per_core=95 memory_pressure=normal swap_used_mb=0 startup_user_agents=2 running_third_party_services=3)"
eq "a busy process among many copies is the parallel case, not the single one" "many-parallel-jobs " \
  "$(sig top_process_cpu_pct=150 busy_group_size=8 load_per_core_pct=200 cpu_used_pct_per_core=95)"
eq "load far above CPU use" "load-above-cpu " \
  "$(sig top_process_cpu_pct=40 busy_group_size=1 load_per_core_pct=900 cpu_used_pct_per_core=70)"
eq "high load with the CPU full is not load-above-cpu" "" \
  "$(sig top_process_cpu_pct=40 busy_group_size=1 load_per_core_pct=900 cpu_used_pct_per_core=99)"
eq "memory pressure warn" "memory-pressure " "$(sig memory_pressure=warn)"
eq "memory pressure critical" "memory-pressure " "$(sig memory_pressure=critical)"
eq "memory pressure unknown matches nothing" "" "$(sig memory_pressure=unknown)"
eq "swap" "heavy-swap " "$(sig memory_pressure=normal swap_used_mb=9000)"
eq "swap under the threshold" "" "$(sig memory_pressure=normal swap_used_mb=8191)"
eq "startup agents and running services" "many-background-services many-startup-agents " \
  "$(sig startup_user_agents=10 running_third_party_services=25)"
eq "a quiet Mac matches nothing" "" \
  "$(sig top_process_cpu_pct=12 busy_group_size=1 load_per_core_pct=40 cpu_used_pct_per_core=10 memory_pressure=normal swap_used_mb=0 startup_user_agents=3 running_third_party_services=5)"
eq "signals the probe did not report match nothing" "" "$(sig cpu_count=8)"

printf 'cpu_count=8\n' > "$TMPD/s"
/bin/bash "$TOOL" match "$TMPD/s" >/dev/null 2>&1; eq "no match exits 3" "3" "$?"

out="$(/bin/bash "$TOOL" show many-startup-agents)"
printf '%s\n' "$out" | grep -q 'class: ask' && ok || bad "show does not print the class of a fix"
printf '%s\n' "$out" | grep -q '任何情況都不做' && ok || bad "show does not print the never list"
eq "never list has five entries" "5" "$(printf '%s\n' "$out" | awk '/^任何情況都不做/ {on=1; next} on && /^  - /' | wc -l | tr -d ' ')"
/bin/bash "$TOOL" show no-such-id >/dev/null 2>&1; eq "show of an unknown id fails" "1" "$?"

# No shipped fix that ends a process or unloads a service is "direct".
bad_direct="$(osascript -l JavaScript -e '
  ObjC.import("Foundation");
  function run(argv) {
    var s = ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null));
    var kb = JSON.parse(s), hits = [];
    kb.problems.forEach(function (p) { p.fixes.forEach(function (f) {
      if (f.class === "direct" && f.command && !/^res-diag\.sh (top|groups|startup|login-items|probe)( |$)/.test(f.command)) { hits.push(p.id + "/" + f.id); }
    }); });
    return hits.join(" ");
  }' plugin/data/problems.json)"
eq "direct fixes only run the read-only subcommands" "" "$bad_direct"

# A personal entry is listed as local, and a broken personal file never hides the shipped ones.
cat > "$TMPD/local.json" <<'JSON'
{ "schema_version": 1, "problems": [ {
  "id": "my-own-case", "title": "自己遇過的狀況", "symptoms": ["慢"],
  "match": { "all": [ { "signal": "swap_used_mb", "op": "gte", "value": 1 } ] },
  "cause": "測試", "fixes": [ { "id": "look", "action": "看一下", "class": "direct", "evidence": "unverified" } ],
  "evidence": { "status": "unverified" } } ] }
JSON
eq "personal entry is listed as local" "local" "$(RES_DIAG_LOCAL_KB="$TMPD/local.json" /bin/bash "$TOOL" list | awk -F'\t' '$1=="my-own-case" {print $3}')"
printf '{ broken' > "$TMPD/broken.json"
eq "a broken personal file leaves the shipped entries" "7" "$(RES_DIAG_LOCAL_KB="$TMPD/broken.json" /bin/bash "$TOOL" list 2>/dev/null | wc -l | tr -d ' ')"
RES_DIAG_LOCAL_KB="$TMPD/broken.json" /bin/bash "$TOOL" validate >/dev/null 2>&1; eq "validate fails on a broken personal file" "1" "$?"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
