#!/usr/bin/env bash
# Run hwinfo.sh in the VM of every project in projects.yaml that runs on this platform,
# then write HARDWARE.md, with one part per platform and one column per project. Run it
# from anywhere:
#
#   ./hwinfo-all.sh                    # every project for this platform that isn't skipped
#   ./hwinfo-all.sh krunkit qemu-virtio  # only these, by name from projects.yaml
#   ./hwinfo-all.sh --report           # only rewrite HARDWARE.md from results/
#
# Each project's VM is created fresh with `make up`, so the boot time is from a first
# boot. `make hwinfo HWINFO_ARGS=--tsv` runs the project's copy of hwinfo.sh in it as
# root, and `make destroy` deletes the VM afterwards. The values are appended to
# results/<platform>/hardware.tsv, and HARDWARE.md shows the newest run of each project
# on each platform, so results from other machines, copied or committed into results/,
# show up too.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
config=$here/projects.yaml

for tool in yq python3; do
  command -v "$tool" >/dev/null || { echo "hwinfo-all.sh needs $tool" >&2; exit 1; }
done

# os, arch, platform, runs_here and describe_machine.
. "$here/platform.sh"
results=$here/results/$platform
tsv=$results/hardware.tsv

report() {
  python3 - "$here" "$(yq -o=json '.' "$config")" <<'PY'
import csv, glob, json, os, sys

here, cfg = sys.argv[1], json.loads(sys.argv[2])
projects = cfg.get("projects", [])
order = [p["name"] for p in projects]
os_names = {"macos": "macOS", "ubuntu": "Ubuntu", "fedora": "Fedora", "debian": "Debian",
            "windows": "Windows", "linux": "Linux"}

def title(platform):
    os_id, _, arch = platform.rpartition("-")
    return f"{os_names.get(os_id, os_id)} {arch}"

def esc(s):
    return s.replace("|", "\\|")

out = ["# Virtual hardware", "",
       "<!-- Written by hwinfo-all.sh from results/*/hardware.tsv. Don't edit by hand. -->", "",
       "What the guest sees in each project's VM, reported by `hwinfo.sh` from inside the "
       "guest right after a fresh `make up`: the platform and firmware, the CPU, the video "
       "and GPU devices with their Vulkan and OpenGL drivers, the OS and the other devices. "
       "Each machine running the VMs has its own part.", ""]
dates, any_results = [], False
for pdir in sorted(d for d in glob.glob(os.path.join(here, "results", "*")) if os.path.isdir(d)):
    path = os.path.join(pdir, "hardware.tsv")
    if not os.path.exists(path):
        continue
    runs = {}  # label -> (run_at, [(section, field, value)])
    with open(path, newline="") as f:
        for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
            if None in r.values() or None in r:
                continue                              # malformed row
            at, rows = runs.get(r["label"], ("", []))
            if r["run_at"] > at:
                at, rows = r["run_at"], []
            if r["run_at"] == at:
                rows.append((r["section"], r["field"], r["value"]))
            runs[r["label"]] = (at, rows)
    if not runs:
        continue
    any_results = True
    cols = [n for n in order if n in runs] + sorted(n for n in runs if n not in order)
    out += [f"## {title(os.path.basename(pdir))}", ""]
    mpath = os.path.join(pdir, "machine.txt")
    if os.path.exists(mpath):
        machine = dict((k.strip(), v.strip()) for k, _, v in
                       (line.partition(":") for line in open(mpath)) if v.strip())
        labels = (("model", ""), ("cpu", "CPU "), ("gpu", "GPU "), ("memory", ""), ("os", ""))
        parts = [f"{prefix}{machine[k]}" for k, prefix in labels if machine.get(k)]
        if parts:
            out += ["Machine: " + ", ".join(parts) + ".", ""]
    sections, fields, val = [], {}, {}
    for label in cols:
        for sec, fld, v in runs[label][1]:
            if sec not in fields:
                sections.append(sec)
                fields[sec] = []
            if fld not in fields[sec]:
                fields[sec].append(fld)
            val[label, sec, fld] = v
    for sec in sections:
        out += [f"### {sec}", "",
                "| Field | " + " | ".join(f"`{c}`" for c in cols) + " |",
                "| --- |" + " --- |" * len(cols)]
        for fld in fields[sec]:
            out.append(f"| {esc(fld)} | "
                       + " | ".join(esc(val.get((c, sec, fld), "")) for c in cols) + " |")
        out.append("")
    dates += [runs[c][0][:10] for c in cols]

if any_results:
    dates.sort()
    when = dates[0] if dates[0] == dates[-1] else f"{dates[0]} to {dates[-1]}"
    out += ["## Notes", "",
            "- **n/a** means the guest didn't expose the value or the tool to read it is "
            "missing; **none** means it was checked and nothing was found.",
            "- **Vulkan devices** lists each device with its driver: `venus` forwards to the "
            "host's GPU, `llvmpipe` runs on the CPU. **OpenGL renderer** comes from `eglinfo` "
            "without a display.",
            "- **Boot time** comes from `systemd-analyze`, and includes cloud-init installing "
            "the packages. Firmware and loader time only show when the firmware reports them.",
            f"- **Inspected** {when}."]
else:
    out.append("No results yet. Run `./hwinfo-all.sh`.")

with open(os.path.join(here, "HARDWARE.md"), "w") as f:
    f.write("\n".join(out) + "\n")
print(f"Wrote {os.path.join(here, 'HARDWARE.md')}", file=sys.stderr)
PY
}

if [ "${1:-}" = --report ]; then
  report
  exit
fi

selection=("$@")
wanted() {
  [ ${#selection[@]} -eq 0 ] && return 0
  printf '%s\n' "${selection[@]}" | grep -qx "$1"
}
mkdir -p "$results"
describe_machine >"$results/machine.txt"
echo "== $platform: $(sed -n 's/^cpu: //p' "$results/machine.txt")" >&2

current=""
current_args=()
trap '[ -n "$current" ] && make -C "$current" destroy "${current_args[@]}" </dev/null >/dev/null 2>&1' EXIT

failed=()
while IFS=$'\t' read -r name path platforms args; do
  [ -n "$name" ] || continue
  wanted "$name" || continue
  if ! runs_here "$platforms"; then
    echo "== $name: runs on $platforms, not $platform" >&2
    continue
  fi
  dir=$here/$path
  # Each project has its own copy of hwinfo.sh, so it stands on its own.
  if ! cmp -s "$here/hwinfo.sh" "$dir/hwinfo.sh"; then
    echo "== $name: $path/hwinfo.sh differs from hwinfo.sh; copy it over first" >&2
    failed+=("$name")
    continue
  fi
  read -r -a make_args <<<"$args"
  log=$results/$name.hwinfo.log
  : >"$log"
  echo "== $name" >&2

  current=$dir
  current_args=("${make_args[@]}")
  make -C "$dir" destroy "${make_args[@]}" </dev/null >/dev/null 2>&1
  printf '%-40s' "make up" >&2
  start=$SECONDS
  if ! make -C "$dir" up "${make_args[@]}" </dev/null >>"$log" 2>&1; then
    echo " FAILED, see $log" >&2; tail -20 "$log" >&2; failed+=("$name")
  else
    echo " $((SECONDS - start))s" >&2
    printf '%-40s' "make hwinfo" >&2
    rows=$(make -s --no-print-directory -C "$dir" hwinfo "${make_args[@]}" HWINFO_ARGS=--tsv \
             </dev/null 2>>"$log")
    if [ -z "$rows" ]; then
      echo " FAILED, see $log" >&2; tail -20 "$log" >&2; failed+=("$name")
    else
      run_at=$(date '+%Y-%m-%d %H:%M')
      [ -f "$tsv" ] || printf 'run_at\tlabel\tsection\tfield\tvalue\n' >"$tsv"
      printf '%s\n' "$rows" | awk -F'\t' -v at="$run_at" -v label="$name" \
        'NF == 3 { print at "\t" label "\t" $0 }' >>"$tsv"
      echo " $(printf '%s\n' "$rows" | grep -c .) values" >&2
      printf '%s\n' "$rows" | awk -F'\t' '$1 == "Video and GPU" { printf "  %-34s %s\n", $2, $3 }' >&2
    fi
  fi
  make -C "$dir" destroy "${make_args[@]}" </dev/null >/dev/null 2>&1
  current=""
done < <(yq -r '.projects[] | select(.skip != true) |
                [.name, .path, (.platforms | join(" ")), (.args // "")] | @tsv' "$config")

report

if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed: ${failed[*]}" >&2
  exit 1
fi
