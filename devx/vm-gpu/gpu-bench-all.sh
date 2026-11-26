#!/usr/bin/env bash
# Benchmark this machine's GPU, then the GPU in every project listed in projects.yaml
# that runs on this OS, and write GPU.md. Run it from anywhere:
#
#   ./gpu-bench-all.sh                 # this machine, then every project for this OS
#   ./gpu-bench-all.sh krunkit         # only these, by name ("host" is this machine)
#   ./gpu-bench-all.sh --report        # only rewrite GPU.md from results/
#
# Each project's VM is created with `make up`, benchmarked with `make bench`, and deleted
# with `make destroy`. Every system builds the same llama.cpp release: llama_ref in
# projects.yaml, or the newest one when that is empty. Results go to results/<name>.csv;
# an earlier file is renamed with its date first. GPU.md shows every file in results/,
# so results copied in from another machine (a Linux host, say) appear too.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
config=$here/projects.yaml
results=$here/results
os=$(uname -s | tr '[:upper:]' '[:lower:]')
host_label=host-$os

command -v yq >/dev/null || { echo "gpu-bench-all.sh needs yq" >&2; exit 1; }

report() {
  python3 - "$here" "$results" "$(yq -o=json '.' "$config")" <<'PY'
import csv, glob, json, os, re, subprocess, sys

here, results, cfg = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
projects = cfg.get("projects", [])
titles = {"host-darwin": "Mac, no VM", "host-linux": "Linux host, no VM"}
order = ["host-darwin", "host-linux"] + [p["name"] for p in projects]

def load(path):
    with open(path) as f:
        rows = list(csv.DictReader(f))
    if not rows:
        return None
    last = max(r["run_at"] for r in rows)          # newest run only
    return [r for r in rows if r["run_at"] == last]

found = {}
for path in glob.glob(os.path.join(results, "*.csv")):
    name = os.path.basename(path)[:-4]
    if re.search(r"\.\d{8}-\d{4}$", name):        # earlier sessions, kept with their date
        continue
    rows = load(path)
    if rows:
        found[name] = rows
cols = [n for n in order if n in found] + sorted(n for n in found if n not in order)

def device(s):
    s = re.sub(r"^\w+?\d+:\s*", "", s)                     # "Vulkan0: "
    return re.sub(r"\s*\(\d+ MiB, \d+ MiB free\)$", "", s)  # "(16384 MiB, 16384 MiB free)"

def get(rows, mode, test):
    for r in rows:
        if r["mode"] == mode and r["test"] == test:
            return r
    return None

def tps(r):
    if r is None:
        return "–"
    x = float(r["tokens_per_s"])
    return f"{x:,.0f}" if x >= 100 else f"{x:.1f}"

def ratio(g, c):
    if g is None or c is None:
        return "–"
    return f"{float(g['tokens_per_s']) / float(c['tokens_per_s']):.1f}x"

def info(rows, test, none="none"):
    r = get(rows, "info", test)
    if r is None and test == "gpu":
        r = get(rows, "gpu", "pp512")              # results written before the info rows
    return device(r["device"]) if r and r["device"] not in ("", "none") else none

def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()
    except OSError:
        return ""

out = ["# GPU benchmark", "",
       "<!-- Written by gpu-bench-all.sh from results/*.csv. Don't edit by hand. -->", "",
       "Tokens per second from llama.cpp's `llama-bench`, on the host itself and in each "
       "project's VM, measured with `gpu-bench-all.sh`. Higher is better.", ""]
if cols:
    out += ["| | " + " | ".join(titles.get(n, f"`{n}`") for n in cols) + " |",
            "| --- |" + " ---: |" * len(cols)]
    def line(label, f):
        out.append(f"| {label} | " + " | ".join(f(found[n]) for n in cols) + " |")
    line("Backend", lambda r: r[0]["backend"].capitalize())
    line("GPU used", lambda r: info(r, "gpu"))
    line("OpenGL renderer", lambda r: info(r, "opengl", "–"))
    line("GPU, prompt (pp512)", lambda r: tps(get(r, "gpu", "pp512")))
    line("GPU, generation (tg128)", lambda r: tps(get(r, "gpu", "tg128")))
    line("CPU only, prompt (pp512)", lambda r: tps(get(r, "cpu", "pp512")))
    line("CPU only, generation (tg128)", lambda r: tps(get(r, "cpu", "tg128")))
    line("CPU threads", lambda r: (get(r, "cpu", "pp512") or {"threads": "–"})["threads"])
    line("GPU speedup, prompt", lambda r: ratio(get(r, "gpu", "pp512"), get(r, "cpu", "pp512")))
    line("GPU speedup, generation", lambda r: ratio(get(r, "gpu", "tg128"), get(r, "cpu", "tg128")))
    first = found[cols[0]][0]
    dates = sorted(found[n][0]["run_at"][:10] for n in cols)
    when = dates[0] if dates[0] == dates[-1] else f"{dates[0]} to {dates[-1]}"
    refs = sorted({f"{found[n][0]['llama_ref']} ({found[n][0]['llama_commit']})" for n in cols})
    hosts = sorted({found[n][0]["host"] for n in cols if n.startswith("host-")})
    out += ["",
            "- **pp512** processes a 512-token prompt and **tg128** generates 128 tokens. Each "
            "value is the mean of 3 repetitions. Prompt processing is mostly compute, so it "
            "shows a GPU best; generation is mostly memory bandwidth.",
            f"- **Model:** `{first['model']}`, with every layer on the GPU (`-ngl 99`) for the "
            "GPU rows and `-dev none -ngl 0` for the CPU rows.",
            "- **GPU used none** means Vulkan found no GPU in that VM, so only the CPU rows are "
            "measured. Mesa's software renderer, llvmpipe, doesn't count as a GPU. An "
            "**OpenGL renderer** of llvmpipe means OpenGL runs on the CPU too.",
            "- **CPU threads** follows each VM's vCPUs, so the CPU rows compare the VMs as the "
            "projects configure them, not the hypervisors at equal size.",
            f"- **llama.cpp:** {', '.join(refs)}.",
            f"- **Measured** {when}" + (f", on {'; '.join(hosts)}." if hosts else ".")]
    chip = sh("sysctl -n machdep.cpu.brand_string")
    if chip and "host-darwin" in found:
        out.append(f"- **Mac:** {chip}, macOS {sh('sw_vers --productVersion')}.")
else:
    out.append("No results yet. Run `./gpu-bench-all.sh`.")
missing = [f"`{p['name']}` ({p['host']})" for p in projects
           if not p.get("skip") and p["name"] not in found]
if missing and cols:
    out.append(f"- **No results yet:** {', '.join(missing)}. Run `gpu-bench-all.sh` on that "
               "OS and copy its `results/*.csv` here.")
for p in projects:
    if p.get("skip"):
        out.append(f"- **Not measured:** `{p['name']}`" + (f", {p['reason']}." if p.get("reason") else "."))

with open(os.path.join(here, "GPU.md"), "w") as f:
    f.write("\n".join(out) + "\n")
print(f"Wrote {os.path.join(here, 'GPU.md')}", file=sys.stderr)
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

keep_old() {
  local f=$results/$1.csv
  [ -f "$f" ] && mv "$f" "$results/$1.$(date -r "$f" +%Y%m%d-%H%M).csv"
  return 0
}

# step LABEL LOG COMMAND...: run quietly, print the time, show the log's tail on failure.
step() {
  local label=$1 log=$2; shift 2
  printf '%-40s' "$label" >&2
  local start=$SECONDS
  if "$@" </dev/null >>"$log" 2>&1; then
    echo " $((SECONDS - start))s" >&2
  else
    echo " FAILED, see $log" >&2
    tail -20 "$log" >&2
    return 1
  fi
}

ref=$(yq '.llama_ref // ""' "$config")
if [ -z "$ref" ]; then
  # Releases are tagged b<number>, such as b6000.
  ref=$(git ls-remote --tags --refs https://github.com/ggml-org/llama.cpp |
        sed -n 's|.*refs/tags/\(b[0-9][0-9]*\)$|\1|p' | sort -k1.2 -n | tail -1)
  [ -n "$ref" ] || { echo "Could not find the newest llama.cpp release." >&2; exit 1; }
fi
echo "== llama.cpp $ref on every system" >&2

current=""
current_args=()
trap '[ -n "$current" ] && make -C "$current" destroy "${current_args[@]}" </dev/null >/dev/null 2>&1' EXIT

failed=()

if wanted host || wanted "$host_label"; then
  echo "== This machine ($host_label)" >&2
  keep_old "$host_label"
  log=$results/$host_label.run.log
  : >"$log"
  if ! step "gpu-bench.sh" "$log" env LABEL="$host_label" LLAMA_REF="$ref" \
         WORK="$results/host-work" RESULTS="$results" "$here/gpu-bench.sh"; then
    failed+=("$host_label")
  fi
fi

while IFS=$'\t' read -r name path host args; do
  [ -n "$name" ] || continue
  wanted "$name" || continue
  if [ "$host" != "$os" ]; then
    echo "== $name: runs on $host, skipping on $os" >&2
    continue
  fi
  dir=$here/$path
  # Each project has its own copy of gpu-bench.sh, so it stands on its own.
  if ! cmp -s "$here/gpu-bench.sh" "$dir/gpu-bench.sh"; then
    echo "== $name: $path/gpu-bench.sh differs from gpu-bench.sh; copy it over first" >&2
    failed+=("$name")
    continue
  fi
  read -r -a make_args <<<"$args"
  log=$results/$name.run.log
  : >"$log"
  echo "== $name" >&2
  keep_old "$name"

  current=$dir
  current_args=("${make_args[@]}")
  make -C "$dir" destroy "${make_args[@]}" </dev/null >/dev/null 2>&1
  if step "make up" "$log" make -C "$dir" up "${make_args[@]}" &&
     step "make gpu" "$log" make -C "$dir" gpu "${make_args[@]}" &&
     step "make bench" "$log" make -C "$dir" bench "${make_args[@]}" LABEL="$name" LLAMA_REF="$ref"; then
    cp "$dir/results/$name.csv" "$results/$name.csv"
    grep -E '^\| (gpu|cpu) ' "$log" >&2
  else
    failed+=("$name")
  fi
  make -C "$dir" destroy "${make_args[@]}" </dev/null >/dev/null 2>&1
  current=""
done < <(yq -r '.projects[] | select(.skip != true) | [.name, .path, .host, (.args // "")] | @tsv' "$config")

report

if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed: ${failed[*]}" >&2
  exit 1
fi
