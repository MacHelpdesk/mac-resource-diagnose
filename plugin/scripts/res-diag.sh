#!/bin/bash
# res-diag — measure what is using this Mac's CPU and memory and what starts at login,
# and look the result up in a knowledge base of known situations.
#
#   res-diag.sh probe [RESOURCE]      what can be measured, one signal=value per line.
#                                     RESOURCE is cpu, memory or startup; without it,
#                                     all three
#   res-diag.sh match [--resource RESOURCE] [SIGNALS_FILE]
#                                     known situations these signals fit (id, evidence
#                                     status, origin, title; tab separated). Without a
#                                     file it runs the probe. With a resource (cpu,
#                                     memory, startup or general) only the situations
#                                     of that resource are compared, and without a
#                                     file only that resource is measured; general
#                                     measures all three. --resource may stand before
#                                     or after the file. Exit 3: no match.
#                                     probe and match exit 64 and write nothing to
#                                     stdout for any other argument
#   res-diag.sh list                  every known situation
#   res-diag.sh show ID               one situation: its resource, symptoms, cause, what
#                                     can be done
#   res-diag.sh validate              check problems.json and the personal additions
#   res-diag.sh top [N] [cpu|mem]     the N processes (default 15) using the most CPU or
#                                     memory: cpu_pct, rss_mb, pid, kind, owner, name
#   res-diag.sh groups [N]            the same processes added up by owner (an app
#                                     bundle, or the program name): owner, processes,
#                                     cpu_pct, rss_mb. Sorted by CPU
#   res-diag.sh startup               launchd items that can start without being opened:
#                                     source, label, run_at_load, keep_alive, pid, program
#   res-diag.sh label LABEL           every launchd property list that carries LABEL, in
#                                     the user folder, /Library and /System/Library:
#                                     source, path. Compares the parsed label, not the
#                                     file name. Exit 5: a folder or file could not be
#                                     read, so the list may be incomplete
#   res-diag.sh login-items           names in System Settings > Login Items > Open at
#                                     Login. Asks System Events, so macOS may show a
#                                     permission prompt the first time
#
# Every subcommand reads; none ends a process, unloads a service or changes a setting.
# Those are decided in the cpu-fix, memory-fix and startup-fix skills.
#
# Nothing here parses text that changes with the system language: numbers come from
# sysctl and from ps with LC_ALL=C, launchd items from property lists.
#
# kind is one of: system (the program lives in /System, /usr or /sbin), agent (started
# by a property list in ~/Library/LaunchAgents), app (inside an .app bundle), other.
#
# The knowledge base is ../data/problems.json. A person's own additions go in
# ~/.config/mac-resource-diagnose/problems.local.json; see README.md.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
KB="${RES_DIAG_KB:-$HERE/../data/problems.json}"
LOCAL_KB="${RES_DIAG_LOCAL_KB:-$HOME/.config/mac-resource-diagnose/problems.local.json}"
KBJS="$HERE/kb.js"

USER_AGENTS="${RES_DIAG_USER_AGENTS:-$HOME/Library/LaunchAgents}"
SYS_AGENTS="${RES_DIAG_SYS_AGENTS:-/Library/LaunchAgents}"
SYS_DAEMONS="${RES_DIAG_SYS_DAEMONS:-/Library/LaunchDaemons}"
OS_AGENTS="${RES_DIAG_OS_AGENTS:-/System/Library/LaunchAgents}"
OS_DAEMONS="${RES_DIAG_OS_DAEMONS:-/System/Library/LaunchDaemons}"
TAB="$(printf '\t')"

TMPD=""
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD"; }
trap cleanup EXIT
tmpdir() { [ -n "$TMPD" ] || TMPD="$(mktemp -d)"; }

# plist_get FILE KEYPATH: the raw value, or nothing when the key is missing
plist_get() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

ps_text() {
  if [ -n "${RES_DIAG_PS:-}" ]; then cat "$RES_DIAG_PS" 2>/dev/null; return; fi
  LC_ALL=C ps -Ao pid=,ppid=,pcpu=,rss=,comm= 2>/dev/null
}
launchctl_text() {
  if [ -n "${RES_DIAG_LAUNCHCTL:-}" ]; then cat "$RES_DIAG_LAUNCHCTL" 2>/dev/null; return; fi
  launchctl list 2>/dev/null
}
sysctl_value() { # OVERRIDE NAME
  if [ -n "$1" ]; then printf '%s\n' "$1"; return; fi
  LC_ALL=C sysctl -n "$2" 2>/dev/null
}

# rows: pid, ppid, cpu, rss_kb, path. Tab separated; control characters in the path
# become "?", so a process name can never add a line or a column.
rows() {
  ps_text | awk '{
    pid = $1; ppid = $2; cpu = $3; rss = $4; path = $0
    sub(/^[ \t]*[0-9]+[ \t]+[0-9]+[ \t]+[0-9.]+[ \t]+[0-9]+[ \t]+/, "", path)
    gsub(/[[:cntrl:]]/, "?", path)
    if (pid ~ /^[0-9]+$/ && ppid ~ /^[0-9]+$/ && cpu ~ /^[0-9]+(\.[0-9]+)?$/ && rss ~ /^[0-9]+$/ && path != "")
      printf "%s\t%s\t%s\t%s\t%s\n", pid, ppid, cpu, rss, path
  }'
}

ncpu() {
  local n
  n="$(sysctl_value "${RES_DIAG_NCPU:-}" hw.ncpu)"
  case "$n" in ''|*[!0-9]*|0) return 1 ;; esac
  echo "$n"
}

# label_of FILE: the Label of a launchd property list, with control characters and tabs
# replaced, or nothing
label_of() { plist_get "$1" Label | tr -d '\n' | tr '[:cntrl:]' '?'; }

# starts_itself FILE: yes when launchd starts the item without anything opening it
starts_itself() {
  local r k
  r="$(plist_get "$1" RunAtLoad)"
  k="$(plist_get "$1" KeepAlive)"
  if [ "$r" = "true" ]; then echo yes; return; fi
  if [ -n "$k" ] && [ "$k" != "false" ]; then echo yes; return; fi
  echo no
}

probe_cpu() {
  local n la
  if n="$(ncpu)"; then echo "cpu_count=$n"; else n=""; fi

  rows | awk -F'\t' -v n="${n:-0}" '
    { c = $3 + 0; sum += c; cnt++
      if (c > max) max = c
      if (c >= 50) busy++
      if (c >= 10) { name = $5; sub(/.*\//, "", name); g[name]++; if (g[name] > gmax) gmax = g[name] } }
    END {
      if (cnt == 0) exit
      printf "process_count=%d\n", cnt
      if (n > 0) printf "cpu_used_pct_per_core=%d\n", sum / n
      printf "top_process_cpu_pct=%d\nbusy_processes=%d\nbusy_group_size=%d\n", max, busy, gmax
    }'

  la="$(sysctl_value "${RES_DIAG_LOADAVG:-}" vm.loadavg)"
  if [ -n "$n" ]; then
    printf '%s\n' "$la" | awk -v n="$n" '{
      gsub(/[{}]/, "")
      if (NF >= 2 && $1 ~ /^[0-9.]+$/ && $2 ~ /^[0-9.]+$/)
        printf "load_per_core_pct=%d\nload5_per_core_pct=%d\n", $1 * 100 / n, $2 * 100 / n
    }'
  fi
  return 0
}

probe_memory() {
  local level free swap
  level="$(sysctl_value "${RES_DIAG_PRESSURE:-}" kern.memorystatus_vm_pressure_level)"
  case "$level" in
    1) echo "memory_pressure=normal" ;;
    2) echo "memory_pressure=warn" ;;
    4) echo "memory_pressure=critical" ;;
    *) echo "memory_pressure=unknown" ;;
  esac
  free="$(sysctl_value "${RES_DIAG_MEMLEVEL:-}" kern.memorystatus_level)"
  case "$free" in ''|*[!0-9]*) ;; *) echo "memory_free_pct=$free" ;; esac
  swap="$(sysctl_value "${RES_DIAG_SWAP:-}" vm.swapusage | sed -nE 's/.*used = ([0-9]+)(\.[0-9]+)?M.*/\1/p')"
  [ -n "$swap" ] && echo "swap_used_mb=$swap"
  return 0
}

probe_startup() {
  local f c
  c=0
  for f in "$USER_AGENTS"/*.plist; do
    [ -f "$f" ] || continue
    [ "$(starts_itself "$f")" = yes ] && c=$((c+1))
  done
  echo "startup_user_agents=$c"
  c=0
  for f in "$SYS_AGENTS"/*.plist "$SYS_DAEMONS"/*.plist; do
    [ -f "$f" ] && c=$((c+1))
  done
  echo "startup_system_items=$c"

  # Services of this login session that are running and are not Apple's. Entries named
  # application.* are apps someone opened, not services.
  tmpdir
  launchctl_text > "$TMPD/launchctl"
  if [ -s "$TMPD/launchctl" ]; then
    c="$(awk '$1 ~ /^[0-9]+$/ && $3 != "" && $3 !~ /^com\.apple\./ && $3 !~ /^application\./' "$TMPD/launchctl" | wc -l | tr -d ' ')"
    echo "running_third_party_services=$c"
  fi
  return 0
}

# probe [RESOURCE]: the signals of one resource, or of all three. Which signal belongs to
# which resource is also written in problems.json ("resource"); a test compares the two.
probe() {
  case "${1:-}" in
    '') probe_cpu; probe_memory; probe_startup ;;
    cpu) probe_cpu ;;
    memory) probe_memory ;;
    startup) probe_startup ;;
    *) echo "resource must be cpu, memory or startup" >&2; return 64 ;;
  esac
}

# agent_pids: the pids of processes started from ~/Library/LaunchAgents, one per line
agent_pids() {
  local f label
  for f in "$USER_AGENTS"/*.plist; do
    [ -f "$f" ] || continue
    label="$(label_of "$f")"
    [ -n "$label" ] || continue
    launchctl_text | awk -v l="$label" '$3 == l && $1 ~ /^[0-9]+$/ { print $1 }'
  done
}

# classified: cpu, rss_mb, pid, kind, owner, name. Tab separated.
classified() {
  tmpdir
  agent_pids > "$TMPD/agents"
  rows | awk -F'\t' -v agents="$TMPD/agents" '
    BEGIN { while ((getline p < agents) > 0) a[p] = 1 }
    {
      path = $5; name = path; sub(/.*\//, "", name)
      owner = name
      i = index(path, ".app/")
      if (i > 0) { owner = substr(path, 1, i + 3); sub(/.*\//, "", owner) }
      if (path ~ /^\/(System|usr|sbin|bin)\//) kind = "system"
      else if ($1 in a) kind = "agent"
      else if (i > 0) kind = "app"
      else kind = "other"
      printf "%s\t%d\t%s\t%s\t%s\t%s\n", $3, $4 / 1024, $1, kind, owner, name
    }'
}

number() { case "$1" in ''|*[!0-9]*|0) return 1 ;; esac; }

top() {
  local n="${1:-15}" by="${2:-cpu}"
  number "$n" || { echo "N must be a positive number" >&2; return 64; }
  case "$by" in
    cpu) classified | sort -t "$TAB" -k1,1nr -k2,2nr | sed -n "1,${n}p" ;;
    mem) classified | sort -t "$TAB" -k2,2nr -k1,1nr | sed -n "1,${n}p" ;;
    *) echo "sort by cpu or mem" >&2; return 64 ;;
  esac
}

groups() {
  local n="${1:-15}"
  number "$n" || { echo "N must be a positive number" >&2; return 64; }
  classified | awk -F'\t' '
    { cnt[$5]++; cpu[$5] += $1; mem[$5] += $2 }
    END { for (o in cnt) printf "%s\t%d\t%d\t%d\n", o, cnt[o], cpu[o], mem[o] }' \
    | sort -t "$TAB" -k3,3nr -k4,4nr | sed -n "1,${n}p"
}

startup() {
  local source dir f label pid program
  for source in user-agent system-agent system-daemon; do
    case "$source" in
      user-agent) dir="$USER_AGENTS" ;;
      system-agent) dir="$SYS_AGENTS" ;;
      system-daemon) dir="$SYS_DAEMONS" ;;
    esac
    for f in "$dir"/*.plist; do
      [ -f "$f" ] || continue
      label="$(label_of "$f")"
      [ -n "$label" ] || label="?"
      # A system daemon runs outside this login session, so launchctl list does not show it.
      if [ "$source" = system-daemon ]; then
        pid="unknown"
      else
        pid="$(launchctl_text | awk -v l="$label" '$3 == l { print ($1 ~ /^[0-9]+$/) ? $1 : "-"; found = 1; exit } END { if (!found) print "not-loaded" }')"
      fi
      program="$(plist_get "$f" Program)"
      [ -n "$program" ] || program="$(plist_get "$f" ProgramArguments.0)"
      program="$(printf '%s' "$program" | tr -d '\n' | tr '[:cntrl:]' '?')"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$source" "$label" \
        "$([ "$(plist_get "$f" RunAtLoad)" = true ] && echo yes || echo no)" \
        "$(k="$(plist_get "$f" KeepAlive)"; [ -n "$k" ] && [ "$k" != false ] && echo yes || echo no)" \
        "$pid" "${program:-?}"
    done
  done
}

# label_sources LABEL: source and path of every property list whose Label is LABEL.
# launchctl disable records a label, not a file, so a fix has to know every file that
# carries it. labels.js parses each property list; a folder or file it could not read
# comes back as an "incomplete" line, which goes to stderr and makes the status 5, so
# "nothing else has this label" is never confused with "could not look".
label_sources() {
  local status=0
  tmpdir
  osascript -l JavaScript "$HERE/labels.js" "$1" \
    user-agent "$USER_AGENTS" system-agent "$SYS_AGENTS" system-daemon "$SYS_DAEMONS" \
    os-agent "$OS_AGENTS" os-daemon "$OS_DAEMONS" > "$TMPD/labels" 2>/dev/null \
    || { echo "could not read the launchd folders" >&2; return 5; }
  awk -F'\t' '$1 != "incomplete" && NF == 2' "$TMPD/labels"
  if grep -q "^incomplete$TAB" "$TMPD/labels"; then
    awk -F'\t' '$1 == "incomplete" { print "could not read: " $2 }' "$TMPD/labels" >&2
    status=5
  fi
  return "$status"
}

login_items() {
  if [ -n "${RES_DIAG_LOGIN_ITEMS:-}" ]; then cat "$RES_DIAG_LOGIN_ITEMS"; return; fi
  osascript -l JavaScript -e 'Application("System Events").loginItems.name().join("\n")' 2>/dev/null \
    || { echo "could not read the login items: System Events did not answer (the permission prompt may have been declined)" >&2; return 1; }
}

kb() { osascript -l JavaScript "$KBJS" "$@"; }

case "${1:-}" in
  probe)
    # No argument measures everything. Exactly one names a resource. Anything else,
    # an empty argument included, is a usage error: it must never widen to everything.
    case $# in
      1) probe ;;
      2) case "$2" in
           cpu|memory|startup) probe "$2" ;;
           *) echo "resource must be cpu, memory or startup" >&2; exit 64 ;;
         esac ;;
      *) echo "usage: $0 probe [cpu|memory|startup]" >&2; exit 64 ;;
    esac
    ;;
  match)
    shift
    # scoped and given record that an argument was passed, apart from its value, so an
    # empty value is refused instead of being read as "not passed".
    resource=""; scoped=no; file=""; given=no
    while [ $# -gt 0 ]; do
      case "$1" in
        --resource)
          [ $# -ge 2 ] || { echo "--resource needs a value" >&2; exit 64; }
          [ "$scoped" = no ] || { echo "--resource given twice" >&2; exit 64; }
          case "$2" in
            cpu|memory|startup|general) ;;
            *) echo "resource must be cpu, memory, startup or general" >&2; exit 64 ;;
          esac
          resource="$2"; scoped=yes; shift 2 ;;
        -*) echo "unknown option" >&2; exit 64 ;;
        '') echo "empty file name" >&2; exit 64 ;;
        *)
          [ "$given" = no ] || { echo "more than one signals file" >&2; exit 64; }
          file="$1"; given=yes; shift ;;
      esac
    done
    tmpdir
    if [ "$given" = yes ]; then
      cp "$file" "$TMPD/signals" || exit 1
    else
      # A general situation may use the signals of any resource.
      case "$resource" in ''|general) probe ;; *) probe "$resource" ;; esac > "$TMPD/signals"
    fi
    if [ "$scoped" = yes ]; then
      kb match "$KB" "$LOCAL_KB" "$TMPD/signals" "$resource" > "$TMPD/matched" || exit 1
    else
      kb match "$KB" "$LOCAL_KB" "$TMPD/signals" > "$TMPD/matched" || exit 1
    fi
    cat "$TMPD/matched"
    [ -s "$TMPD/matched" ] || exit 3
    ;;
  list) kb list "$KB" "$LOCAL_KB" ;;
  show) [ -n "${2:-}" ] || { echo "usage: $0 show ID" >&2; exit 64; }; kb show "$KB" "$LOCAL_KB" "$2" ;;
  validate) kb validate "$KB" "$LOCAL_KB" ;;
  top) top "${2:-15}" "${3:-cpu}" ;;
  groups) groups "${2:-15}" ;;
  startup) startup ;;
  label)
    [ $# -eq 2 ] || { echo "usage: $0 label LABEL" >&2; exit 64; }
    case "$2" in
      ''|*[!A-Za-z0-9._-]*) echo "a label has letters, digits, dots, hyphens and underscores only" >&2; exit 64 ;;
    esac
    label_sources "$2"
    ;;
  login-items) login_items ;;
  # The usage text is the header comment up to its second empty comment line: the
  # summary and the list of subcommands.
  *) awk 'NR == 1 { next } /^#$/ { if (++gap == 2) exit } { sub(/^# ?/, ""); print }' "$0" >&2; exit 64 ;;
esac
