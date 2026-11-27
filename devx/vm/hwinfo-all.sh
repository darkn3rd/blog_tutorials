#!/usr/bin/env bash
# Run hwinfo.sh in the VM of every tutorial listed in bench.yaml, then write HARDWARE.md
# with one column per tutorial. Run it from anywhere:
#
#   ./hwinfo-all.sh                   # every tutorial that isn't skipped
#   ./hwinfo-all.sh lima_ansible ...  # only these, by name from bench.yaml
#   ./hwinfo-all.sh --report          # only rewrite HARDWARE.md from hardware.tsv
#
# Each tutorial's VM is created fresh with `make up`, without provisioning, so the boot
# time is from a first boot. hwinfo.sh runs in it as root through the tutorial's own
# Ansible inventory, and `make destroy` deletes the VM afterwards. Results are appended to
# hardware.tsv next to this script, and HARDWARE.md shows the newest run of each tutorial.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
config=$here/bench.yaml
tsv=$here/hardware.tsv

for tool in yq ansible python3; do
  command -v "$tool" >/dev/null || { echo "hwinfo-all.sh needs $tool" >&2; exit 1; }
done

report() {
  python3 - "$here" "$tsv" "$(yq -o=json '.' "$config")" <<'PY'
import csv, json, os, subprocess, sys

here, tsv, cfg = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])

runs = {}  # label -> (run_at, [(section, field, value)])
if os.path.exists(tsv):
    with open(tsv, newline="") as f:
        for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
            if None in r.values() or None in r:
                continue  # malformed row
            at, rows = runs.get(r["label"], ("", []))
            if r["run_at"] > at:
                at, rows = r["run_at"], []
            if r["run_at"] == at:
                rows.append((r["section"], r["field"], r["value"]))
            runs[r["label"]] = (at, rows)

cols, skipped = [], []
for t in cfg.get("tutorials", []):
    if t.get("skip"):
        skipped.append(t)
    elif t["path"] in runs:
        cols.append(t["path"])

sections, fields, val = [], {}, {}
for label in cols:
    for sec, fld, v in runs[label][1]:
        if sec not in fields:
            sections.append(sec)
            fields[sec] = []
        if fld not in fields[sec]:
            fields[sec].append(fld)
        val[label, sec, fld] = v

def esc(s):
    return s.replace("|", "\\|")

def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()
    except OSError:
        return ""

out = ["# Virtual hardware", "",
       "<!-- Written by hwinfo-all.sh from hardware.tsv. Don't edit by hand. -->", "",
       "What the guest sees in each tutorial's VM, reported by `hwinfo.sh` from inside the "
       "guest right after a fresh `make up`.", ""]
if not cols:
    out += ["No results yet. Run `./hwinfo-all.sh`.", ""]
for sec in sections:
    out += [f"## {sec}", "",
            "| Field | " + " | ".join(f"`{c}`" for c in cols) + " |",
            "| --- |" + " --- |" * len(cols)]
    for fld in fields[sec]:
        out.append(f"| {esc(fld)} | "
                   + " | ".join(esc(val.get((c, sec, fld), "")) for c in cols) + " |")
    out.append("")

chip = sh("sysctl -n machdep.cpu.brand_string")
macos = sh("sw_vers --productVersion")
dates = sorted(runs[c][0][:10] for c in cols)
when = (f"{dates[0]} to {dates[-1]}" if dates and dates[0] != dates[-1]
        else (dates[0] if dates else ""))
out += ["- **n/a** means the guest didn't expose the value or the tool to read it is missing; "
        "**none** means it was checked and nothing was found.",
        "- **Boot time** comes from `systemd-analyze`. Firmware and loader time only show "
        "when the firmware reports them to the guest.",
        f"- **Measured on** an {chip} with macOS {macos}" + (f", {when}." if when else ".")]
for t in skipped:
    out.append(f"- **Not inspected:** `{t['path']}`"
               + (f", {t['reason']}." if t.get("reason") else "."))

with open(os.path.join(here, "HARDWARE.md"), "w") as f:
    f.write("\n".join(out) + "\n")
print(f"Wrote {os.path.join(here, 'HARDWARE.md')}", file=sys.stderr)
PY
}

if [ "${1:-}" = --report ]; then
  report
  exit
fi

current=""
trap '[ -n "$current" ] && (cd "$current" && make destroy </dev/null >/dev/null 2>&1)' EXIT

log=$(mktemp)
failed=()
fail() {
  echo " FAILED" >&2
  tail -20 "$log" >&2
  echo "== $path failed; destroying its VM and moving on" >&2
  (cd "$dir" && make destroy </dev/null >/dev/null 2>&1)
  current=""
  failed+=("$path")
}

while read -r name path; do
  [ -n "$name" ] || continue
  if [ $# -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$name"; then
    continue
  fi
  dir=$here/$path
  echo "== $path" >&2

  current=$dir
  (cd "$dir" && make destroy) </dev/null >/dev/null 2>&1
  printf '%-40s' "make up" >&2
  if ! (cd "$dir" && make up) </dev/null >"$log" 2>&1; then fail; continue; fi
  echo " ok" >&2

  printf '%-40s' "hwinfo.sh" >&2
  # The Vagrant tutorials' inventories read the SSH config that `make playbook` saves.
  if [ -f "$dir/Vagrantfile" ]; then
    (cd "$dir" && vagrant ssh-config >.vagrant/ssh.config) 2>>"$log"
  fi
  json=$(cd "$dir" && ANSIBLE_LOAD_CALLBACK_PLUGINS=1 ANSIBLE_STDOUT_CALLBACK=ansible.posix.json \
         ansible all -b -m script -a "$here/hwinfo.sh --tsv" </dev/null 2>>"$log")
  rows=$(printf '%s' "$json" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    host = next(iter(data["plays"][0]["tasks"][0]["hosts"].values()))
except (ValueError, LookupError, StopIteration):
    sys.exit("could not read the Ansible output")
if host.get("failed") or host.get("unreachable") or host.get("rc", 0) != 0:
    sys.exit(host.get("msg") or host.get("stderr") or "hwinfo.sh failed")
sys.stdout.write(host["stdout"])
' 2>>"$log")
  if [ -z "$rows" ]; then printf '%s\n' "$json" >>"$log"; fail; continue; fi
  run_at=$(date '+%Y-%m-%d %H:%M')
  [ -f "$tsv" ] || printf 'run_at\tlabel\tsection\tfield\tvalue\n' >"$tsv"
  printf '%s\n' "$rows" | awk -v at="$run_at" -v label="$path" 'NF { print at "\t" label "\t" $0 }' >>"$tsv"
  echo " $(printf '%s\n' "$rows" | grep -c .) values" >&2

  (cd "$dir" && make destroy) </dev/null >/dev/null 2>&1
  current=""
done < <(yq -r '.tutorials[] | select(.skip != true) | .name + " " + .path' "$config")
rm -f "$log"

report

if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed: ${failed[*]}" >&2
  exit 1
fi
