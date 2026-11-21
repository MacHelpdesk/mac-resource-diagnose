#!/bin/bash
# test_probe — probe, top, groups, startup and login-items read synthetic process lists,
# launchd listings and property lists.
#
# Every input read from the system has an override (RES_DIAG_*), so these tests never
# depend on what this Mac is running.

set -u
cd "$(dirname "$0")/.." || exit 2
TOOL=plugin/scripts/res-diag.sh
FX=tests/fixtures
TAB="$(printf '\t')"

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

# expect OUTPUT LINE: OUTPUT contains LINE as a whole line
expect()    { printf '%s\n' "$1" | grep -qxF "$2" && ok || bad "missing \"$2\" in: $(printf '%s' "$1" | tr '\n' ' ')"; }
expect_no() { printf '%s\n' "$1" | grep -q "^$2=" && bad "unexpected $2 in: $(printf '%s' "$1" | tr '\n' ' ')" || ok; }
eq()        { [ "$2" = "$3" ] && ok || bad "$1: expected [$2] got [$3]"; }

run() { # ps-fixture, then the subcommand and its arguments
  local ps="$1"; shift
  RES_DIAG_PS="$FX/$ps" \
  RES_DIAG_NCPU="${NCPU-4}" \
  RES_DIAG_LOADAVG="${LOADAVG-{ 12.00 8.00 4.00 \}}" \
  RES_DIAG_PRESSURE="${PRESSURE-1}" \
  RES_DIAG_MEMLEVEL="${MEMLEVEL-55}" \
  RES_DIAG_SWAP="${SWAP-total = 4096.00M  used = 1536.75M  free = 2559.25M  (encrypted)}" \
  RES_DIAG_LAUNCHCTL="${LAUNCHCTL-$FX/launchctl.txt}" \
  RES_DIAG_USER_AGENTS="$FX/agents_user" \
  RES_DIAG_SYS_AGENTS="$FX/agents_system" \
  RES_DIAG_SYS_DAEMONS="$FX/daemons_system" \
  RES_DIAG_LOGIN_ITEMS="$FX/login_items.txt" \
  RES_DIAG_LOCAL_KB=/nonexistent \
  /bin/bash "$TOOL" "$@"
}

# --- probe: several copies of one job
out="$(run ps_parallel.txt probe)"
expect "$out" "cpu_count=4"
expect "$out" "process_count=12"
expect "$out" "cpu_used_pct_per_core=66"        # 266.0 / 4
expect "$out" "top_process_cpu_pct=60"
expect "$out" "busy_processes=1"
expect "$out" "busy_group_size=5"               # the sixth copy is under 10%
expect "$out" "load_per_core_pct=300"
expect "$out" "load5_per_core_pct=200"
expect "$out" "memory_pressure=normal"
expect "$out" "memory_free_pct=55"
expect "$out" "swap_used_mb=1536"
expect "$out" "startup_user_agents=3"           # RunAtLoad true twice, KeepAlive as a dictionary once
expect "$out" "startup_system_items=3"
expect "$out" "running_third_party_services=2"  # not Apple's, not application.*, and has a pid

# --- probe: one busy process
out="$(run ps_single.txt probe)"
expect "$out" "top_process_cpu_pct=185"
expect "$out" "busy_group_size=1"
expect "$out" "process_count=4"

# --- probe: memory pressure levels and values that cannot be read
expect "$(PRESSURE=2 run ps_single.txt probe)" "memory_pressure=warn"
expect "$(PRESSURE=4 run ps_single.txt probe)" "memory_pressure=critical"
expect "$(PRESSURE=7 run ps_single.txt probe)" "memory_pressure=unknown"
out="$(NCPU=zero MEMLEVEL=x SWAP=nothing LOADAVG=garbage run ps_single.txt probe)"
expect_no "$out" cpu_count
expect_no "$out" cpu_used_pct_per_core
expect_no "$out" load_per_core_pct
expect_no "$out" memory_free_pct
expect_no "$out" swap_used_mb
expect "$out" "top_process_cpu_pct=185"
out="$(LAUNCHCTL=/nonexistent run ps_single.txt probe)"
expect_no "$out" running_third_party_services

# --- probe: a process list that cannot be read reports no process signals
out="$(run missing.txt probe)"
expect_no "$out" process_count
expect_no "$out" top_process_cpu_pct
expect "$out" "memory_pressure=normal"

# --- top
out="$(run ps_parallel.txt top 3 cpu)"
eq "top: three lines" "3" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
eq "top cpu: first line" "60.0${TAB}2000${TAB}401${TAB}app${TAB}Example Editor.app${TAB}Example Helper (Renderer)" "$(printf '%s\n' "$out" | sed -n '1p')"
eq "top cpu: a system process" "40.0${TAB}341${TAB}200${TAB}system${TAB}WindowServer${TAB}WindowServer" "$(printf '%s\n' "$out" | sed -n '2p')"
out="$(run ps_parallel.txt top 20 mem)"
eq "top mem: first pid" "401" "$(printf '%s\n' "$out" | sed -n '1p' | cut -f3)"
eq "top: a launch agent's process is kind agent" "agent" "$(printf '%s\n' "$out" | awk -F'\t' '$3==500 {print $4}')"
eq "top: a name with a space, outside any bundle" "other${TAB}worker job${TAB}worker job" "$(printf '%s\n' "$out" | awk -F'\t' '$3==600 {print $4 "\t" $5 "\t" $6}')"
eq "top: every line has six columns" "12" "$(printf '%s\n' "$out" | awk -F'\t' 'NF==6' | wc -l | tr -d ' ')"
run ps_parallel.txt top 0 >/dev/null 2>&1; eq "top: N of 0 is refused" "64" "$?"
run ps_parallel.txt top 5 disk >/dev/null 2>&1; eq "top: unknown sort is refused" "64" "$?"
run ps_parallel.txt top '1p;e date' >/dev/null 2>&1; eq "top: N that is not a number is refused" "64" "$?"

# --- top: hostile process names cannot add a line or a column
out="$(run ps_hostile.txt top 20)"
eq "hostile: two rows survive" "2" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
eq "hostile: six columns each" "2" "$(printf '%s\n' "$out" | awk -F'\t' 'NF==6' | wc -l | tr -d ' ')"
eq "hostile: control characters replaced" "evil?name?col" "$(printf '%s\n' "$out" | awk -F'\t' '$3==800 {print $6}')"

# --- groups
out="$(run ps_parallel.txt groups 3)"
eq "groups: busiest owner" "compiler-frontend${TAB}6${TAB}152${TAB}702" "$(printf '%s\n' "$out" | sed -n '1p')"
eq "groups: an app's helpers are added to the app" "Example Editor.app${TAB}2${TAB}72${TAB}2500" "$(printf '%s\n' "$out" | sed -n '2p')"

# --- startup
out="$(run ps_parallel.txt startup)"
eq "startup: eight items" "8" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
expect "$out" "user-agent${TAB}com.example.sync-agent${TAB}yes${TAB}yes${TAB}500${TAB}/Applications/Sync Thing.app/Contents/MacOS/sync-agent"
expect "$out" "user-agent${TAB}com.example.updater${TAB}yes${TAB}no${TAB}-${TAB}/opt/example/updater"
expect "$out" "user-agent${TAB}com.example.ondemand${TAB}no${TAB}no${TAB}not-loaded${TAB}/opt/example/ondemand"
expect "$out" "user-agent${TAB}com.example.keepdict${TAB}no${TAB}yes${TAB}not-loaded${TAB}/opt/example/keepdict"
expect "$out" "user-agent${TAB}com.example.keepfalse${TAB}no${TAB}no${TAB}not-loaded${TAB}/opt/example/keepfalse"
expect "$out" "system-agent${TAB}org.example.helper${TAB}yes${TAB}no${TAB}912${TAB}/opt/example/helper"
expect "$out" "system-daemon${TAB}org.example.daemon${TAB}yes${TAB}yes${TAB}unknown${TAB}/opt/example/daemon"

# --- login-items
eq "login-items" "Example Player Sync Thing " "$(run ps_single.txt login-items | tr '\n' ' ')"

# --- usage
/bin/bash "$TOOL" >/dev/null 2>&1; eq "no subcommand" "64" "$?"
usage="$(/bin/bash "$TOOL" 2>&1)"
printf '%s\n' "$usage" | grep -q 'res-diag.sh login-items' && ok || bad "usage does not list the last subcommand"
printf '%s\n' "$usage" | grep -q 'Every subcommand reads' && bad "usage runs past the list of subcommands" || ok

# --- probe by resource (docs/spectra/specs/resource-scoped-measurement)
names() { cut -d= -f1 | tr '\n' ' '; }

# spec-example: resource-scoped-measurement / signals per resource
eq "probe cpu" "cpu_count process_count cpu_used_pct_per_core top_process_cpu_pct busy_processes busy_group_size load_per_core_pct load5_per_core_pct " \
  "$(run ps_parallel.txt probe cpu | names)"
eq "probe memory" "memory_pressure memory_free_pct swap_used_mb " "$(run ps_parallel.txt probe memory | names)"
eq "probe startup" "startup_user_agents startup_system_items running_third_party_services " "$(run ps_parallel.txt probe startup | names)"
out="$(run ps_parallel.txt probe gpu 2>/dev/null)"; eq "probe gpu exits 64" "64" "$?"
eq "probe gpu prints nothing" "" "$out"
run ps_parallel.txt probe cpu >/dev/null; eq "probe cpu exits 0" "0" "$?"
# The script and the knowledge base agree on which signal belongs to which resource.
for r in cpu memory startup; do
  eq "signals tagged $r in problems.json" "$(run ps_parallel.txt probe "$r" | cut -d= -f1 | sort | tr '\n' ' ')" \
    "$(osascript -l JavaScript -e '
      ObjC.import("Foundation");
      function run(argv) {
        var kb = JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null)));
        return Object.keys(kb.signals).filter(function (k) { return kb.signals[k].resource === argv[1]; }).join("\n");
      }' plugin/data/problems.json "$r" | sort | tr '\n' ' ')"
done

# spec-example: resource-scoped-measurement / unscoped probe equals the three scoped probes
all="$(run ps_parallel.txt probe | sort)"
parts="$( { run ps_parallel.txt probe cpu; run ps_parallel.txt probe memory; run ps_parallel.txt probe startup; } | sort)"
eq "unscoped probe equals the three scoped probes" "$parts" "$all"
eq "unscoped probe has 14 lines" "14" "$(printf '%s\n' "$all" | wc -l | tr -d ' ')"

# A scoped match without a file probes only that resource.
eq "match --resource memory without a file" "1" "$(SWAP='total = 1.00M  used = 9000.00M  free = 0M' run ps_parallel.txt match --resource memory | grep -c '^heavy-swap')"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
