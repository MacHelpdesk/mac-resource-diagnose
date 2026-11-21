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

# --- resources (docs/spectra/specs/resource-scoped-measurement)

# kbfile NAME SIGNALS_JSON PROBLEM_FIELDS: a small knowledge base with one entry
kbfile() {
  cat > "$TMPD/$1.json" <<JSON
{ "schema_version": 1, "signals": { $2 }, "never": [ { "action": "a", "reason": "r" } ],
  "problems": [ { "id": "one-case", "title": "t", "symptoms": ["s"], $3
    "cause": "c", "fixes": [ { "id": "look", "action": "a", "class": "user", "evidence": "unverified" } ],
    "evidence": { "status": "unverified" } } ] }
JSON
}
valid() { RES_DIAG_KB="$TMPD/$1.json" /bin/bash "$TOOL" validate >/dev/null 2>&1 && echo passes || echo fails; }
LOAD='"load_per_core_pct": { "description": "d", "values": "number", "resource": "cpu" }'
SWAP='"swap_used_mb": { "description": "d", "values": "number", "resource": "memory" }'
ON_SWAP='"match": { "all": [ { "signal": "swap_used_mb", "op": "gte", "value": 1 } ] },'
ON_BOTH='"match": { "all": [ { "signal": "load_per_core_pct", "op": "gte", "value": 1 }, { "signal": "swap_used_mb", "op": "gte", "value": 1 } ] },'

# spec-example: resource-scoped-measurement / resource fields that validate and that do not
/bin/bash "$TOOL" validate >/dev/null 2>&1 && ok || bad "resource: shipped file does not validate"
kbfile nosig "$LOAD, \"swap_used_mb\": { \"description\": \"d\", \"values\": \"number\" }" "\"resource\": \"memory\", $ON_SWAP"
eq "signal without resource" "fails" "$(valid nosig)"
kbfile badsig "$LOAD, \"swap_used_mb\": { \"description\": \"d\", \"values\": \"number\", \"resource\": \"disk\" }" "\"resource\": \"general\", $ON_SWAP"
eq "signal with resource disk" "fails" "$(valid badsig)"
kbfile badentry "$LOAD, $SWAP" "\"resource\": \"network\", $ON_SWAP"
eq "entry with resource network" "fails" "$(valid badentry)"
kbfile crossed "$LOAD, $SWAP" "\"resource\": \"cpu\", $ON_SWAP"
eq "cpu entry with a memory signal" "fails" "$(valid crossed)"
kbfile general "$LOAD, $SWAP" "\"resource\": \"general\", $ON_BOTH"
eq "general entry with signals of two resources" "passes" "$(valid general)"
kbfile sane "$LOAD, $SWAP" "\"resource\": \"memory\", $ON_SWAP"
eq "memory entry with a memory signal" "passes" "$(valid sane)"

# spec-example: resource-scoped-measurement / shipped entries and their resources
res_of() { /bin/bash "$TOOL" show "$1" | sed -n 's/^resource: //p'; }
eq "resource of single-process-busy" "cpu" "$(res_of single-process-busy)"
eq "resource of many-parallel-jobs" "cpu" "$(res_of many-parallel-jobs)"
eq "resource of load-above-cpu" "general" "$(res_of load-above-cpu)"
eq "resource of memory-pressure" "memory" "$(res_of memory-pressure)"
eq "resource of heavy-swap" "memory" "$(res_of heavy-swap)"
eq "resource of many-startup-agents" "startup" "$(res_of many-startup-agents)"
eq "resource of many-background-services" "startup" "$(res_of many-background-services)"
eq "every shipped entry has a resource field" "7" "$(osascript -l JavaScript -e '
  ObjC.import("Foundation");
  function run(argv) {
    var kb = JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null)));
    return kb.problems.filter(function (p) { return typeof p.resource === "string"; }).length;
  }' plugin/data/problems.json)"

# spec-example: resource-scoped-measurement / show prints the resource
/bin/bash "$TOOL" show heavy-swap | grep -qxF 'resource: memory' && ok || bad "show heavy-swap lacks resource: memory"
/bin/bash "$TOOL" show load-above-cpu | grep -qxF 'resource: general' && ok || bad "show load-above-cpu lacks resource: general"

# spec-example: resource-scoped-measurement / matching by resource
printf '%s\n' top_process_cpu_pct=185 busy_group_size=1 load_per_core_pct=60 cpu_used_pct_per_core=50 \
  memory_pressure=normal swap_used_mb=9000 startup_user_agents=12 running_third_party_services=3 > "$TMPD/mix"
m() { /bin/bash "$TOOL" match "$@" 2>/dev/null | ids; }
eq "match FILE" "heavy-swap many-startup-agents single-process-busy " "$(m "$TMPD/mix")"
eq "match --resource cpu FILE" "single-process-busy " "$(m --resource cpu "$TMPD/mix")"
eq "match --resource memory FILE" "heavy-swap " "$(m --resource memory "$TMPD/mix")"
eq "match FILE --resource startup" "many-startup-agents " "$(m "$TMPD/mix" --resource startup)"
eq "match --resource general FILE" "" "$(m --resource general "$TMPD/mix")"
/bin/bash "$TOOL" match --resource general "$TMPD/mix" >/dev/null 2>&1; eq "general with no match exits 3" "3" "$?"
out="$(/bin/bash "$TOOL" match --resource gpu "$TMPD/mix" 2>/dev/null)"; eq "unknown resource exits 64" "64" "$?"
eq "unknown resource prints nothing" "" "$out"
/bin/bash "$TOOL" match --resource >/dev/null 2>&1; eq "--resource without a value exits 64" "64" "$?"

# spec-example: resource-scoped-measurement / the cross-resource entry stays out of the cpu scope
printf '%s\n' top_process_cpu_pct=40 busy_group_size=1 load_per_core_pct=900 cpu_used_pct_per_core=70 > "$TMPD/cross"
eq "cross entry: match FILE" "load-above-cpu " "$(m "$TMPD/cross")"
eq "cross entry: general" "load-above-cpu " "$(m --resource general "$TMPD/cross")"
eq "cross entry: cpu" "" "$(m --resource cpu "$TMPD/cross")"
/bin/bash "$TOOL" match --resource cpu "$TMPD/cross" >/dev/null 2>&1; eq "cross entry: cpu exits 3" "3" "$?"

# spec-example: resource-scoped-measurement / local entry without a resource
cat > "$TMPD/old.json" <<'JSON'
{ "schema_version": 1, "problems": [ {
  "id": "my-case", "title": "t", "symptoms": ["s"],
  "match": { "all": [ { "signal": "swap_used_mb", "op": "gte", "value": 1 } ] },
  "cause": "c", "fixes": [ { "id": "look", "action": "a", "class": "user", "evidence": "unverified" } ],
  "evidence": { "status": "unverified" } } ] }
JSON
printf '%s\n' swap_used_mb=5 memory_pressure=normal > "$TMPD/small"
ml() { RES_DIAG_LOCAL_KB="$TMPD/old.json" /bin/bash "$TOOL" match "$@" 2>/dev/null | ids; }
RES_DIAG_LOCAL_KB="$TMPD/old.json" /bin/bash "$TOOL" validate >/dev/null 2>&1 && ok || bad "a local entry without resource does not validate"
eq "local without resource: match FILE" "my-case " "$(ml "$TMPD/small")"
eq "local without resource: general" "my-case " "$(ml --resource general "$TMPD/small")"
eq "local without resource: memory" "" "$(ml --resource memory "$TMPD/small")"
eq "local without resource: show" "general" "$(RES_DIAG_LOCAL_KB="$TMPD/old.json" /bin/bash "$TOOL" show my-case | sed -n 's/^resource: //p')"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
