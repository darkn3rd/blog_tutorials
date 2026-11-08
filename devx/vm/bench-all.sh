#!/usr/bin/env bash
# Run bench.sh in every tutorial listed in bench.yaml, then write TIMINGS.md with the
# median of each step. Creating the VM and provisioning it are timed as separate steps. Run it from anywhere:
#
#   ./bench-all.sh                    # time every tutorial that isn't skipped
#   ./bench-all.sh lima_ansible ...   # time only these, by name from bench.yaml
#   ./bench-all.sh --report           # only rewrite TIMINGS.md from existing results
#
# Each tutorial's results go to <name>.timings.csv next to this script. Before a tutorial
# is timed again, its previous results file is renamed with its date, so TIMINGS.md only
# reflects the latest session.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
config=$here/bench.yaml

command -v yq >/dev/null || { echo "bench-all.sh needs yq: brew install yq" >&2; exit 1; }

report() {
  python3 - "$here" "$(yq -o=json '.' "$config")" <<'PY'
import csv, json, os, statistics, subprocess, sys

here, cfg = sys.argv[1], json.loads(sys.argv[2])

COLD, WARM, DOWNLOAD = "up, download and create", "up, create", "download"
rows = [
    (COLD, "First `make up`, with download"),
    (DOWNLOAD, "Download, estimated"),
    (WARM, "`make up`, create"),
    ("provision, first run", "`make provision`, first run"),
    ("provision, no changes", "`make provision`, no changes"),
    ("provision, page changed", "`make provision`, page changed"),
    ("provision, page restored", "`make provision`, page restored"),
    ("playbook, page restored", "`make playbook`, page restored"),
    ("playbook, no changes", "`make playbook`, no changes"),
    ("halt", "`make halt`"),
    ("up, from stopped", "`make up`, from stopped"),
    ("up, while running", "`make up`, while running"),
    ("destroy", "`make destroy`"),
]

def fmt(x):
    if x is None:
        return "–"
    if x >= 60:
        m, s = divmod(round(x), 60)
        return f"{m}m {s}s"
    return f"{x:.2f}s" if x < 1 else f"{x:.1f}s"

cols, skipped, dates = [], [], []
for t in cfg.get("tutorials", []):
    if t.get("skip"):
        skipped.append(t)
        continue
    path = os.path.join(here, f"{t['name']}.timings.csv")
    if not os.path.exists(path):
        continue
    steps = {}
    with open(path) as f:
        for r in csv.DictReader(f):
            if r["step"].startswith("download"):
                continue  # recomputed below from the medians
            steps.setdefault(r["step"], []).append(float(r["seconds"]))
            dates.append(r["run_at"][:10])
    med = {k: statistics.median(v) for k, v in steps.items()}
    if COLD in med and WARM in med:
        med[DOWNLOAD] = med[COLD] - med[WARM]
    # Every run times `make halt` once; only cold runs time the download.
    runs = f"{len(steps.get(COLD, []))} cold, {len(steps.get('halt', []))} warm"
    cols.append((t, med, runs))

def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()
    except OSError:
        return ""

chip = sh("sysctl -n machdep.cpu.brand_string")
mem = sh("sysctl -n hw.memsize")
mem = f"{int(mem) // 2**30} GB" if mem.isdigit() else "unknown"
macos = sh("sw_vers --productVersion")
when = f"{min(dates)} to {max(dates)}" if dates and min(dates) != max(dates) else (dates[0] if dates else "")

out = ["# Timings", "",
       "<!-- Written by bench-all.sh from the *.timings.csv results. Don't edit by hand. -->", "",
       "How long each step takes in each tutorial, measured with `bench-all.sh`. Each value is "
       "the median of that tutorial's runs, which keeps one slow or fast run from skewing it.", ""]
if cols:
    out += ["| Step | " + " | ".join(f"`{t['path']}`" for t, _, _ in cols) + " |",
            "| --- |" + " ---: |" * len(cols),
            "| Runs | " + " | ".join(r for _, _, r in cols) + " |"]
    for key, label in rows:
        if any(key in m for _, m, _ in cols):
            out.append(f"| {label} | " + " | ".join(fmt(m.get(key)) for _, m, _ in cols) + " |")
else:
    out.append("No results yet. Run `./bench-all.sh`.")
out.append("")
out.append("- **Creating and provisioning are timed separately.** `make up` creates and boots "
           "the VM without configuring it, and the first `make provision` configures it.")
out += ["- **Download, estimated** is the cold `make up` minus the warm one. A cold run deletes "
        "the image or box with `make purge` first. The estimate also includes any other "
        "first-run work, such as unpacking the image, and it depends on your connection.",
        "- **`make provision`** runs Vagrant's provisioner in the Vagrant tutorials and "
        "`ansible-playbook` from the Mac in the others. `make playbook` runs "
        "`ansible-playbook` from the Mac in the Vagrant tutorials.",
        f"- **Measured on** an {chip} with {mem} of memory and macOS {macos}"
        + (f", {when}." if when else ".")]
for t in skipped:
    out.append(f"- **Not timed:** `{t['path']}`" + (f", {t['reason']}." if t.get("reason") else "."))

with open(os.path.join(here, "TIMINGS.md"), "w") as f:
    f.write("\n".join(out) + "\n")
print(f"Wrote {os.path.join(here, 'TIMINGS.md')}", file=sys.stderr)
PY
}

if [ "${1:-}" = --report ]; then
  report
  exit
fi

cold_runs=$(yq '.cold_runs // 1' "$config")
warm_runs=$(yq '.warm_runs // 3' "$config")
extra_warm=$((warm_runs > cold_runs ? warm_runs - cold_runs : 0))

failed=()
while read -r name path; do
  [ -n "$name" ] || continue
  if [ $# -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$name"; then
    continue
  fi

  dir=$here/$path
  csv=$here/$name.timings.csv
  if [ -f "$csv" ]; then
    mv "$csv" "$here/$name.$(date -r "$csv" +%Y%m%d-%H%M).timings.csv"
  fi

  echo "== $path: $cold_runs cold and $extra_warm more warm runs" >&2
  ok=true
  for ((i = 0; i < cold_runs + extra_warm; i++)); do
    flag=
    [ "$i" -lt "$cold_runs" ] && flag=--cold
    if ! (cd "$dir" && TIMINGS_CSV=$csv "$here/bench.sh" $flag) </dev/null; then
      ok=false
      break
    fi
  done

  if ! $ok; then
    echo "== $path failed; destroying its VM and moving on" >&2
    (cd "$dir" && make destroy </dev/null >/dev/null 2>&1)
    failed+=("$path")
  fi
done < <(yq -r '.tutorials[] | select(.skip != true) | .name + " " + .path' "$config")

report

if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed: ${failed[*]}" >&2
  exit 1
fi
