#!/usr/bin/env bash
# Portable GPU vs CPU benchmark using llama.cpp's llama-bench (Linux and macOS).
#
# Usage:
#   ./gpu-bench.sh                  # Metal on macOS, Vulkan on Linux
#   BACKEND=cuda ./gpu-bench.sh     # NVIDIA with the CUDA toolkit installed
#   BACKEND=hip ./gpu-bench.sh      # AMD with ROCm installed
#   MODEL=/path/model.gguf ./gpu-bench.sh
#   LLAMA_REF=<tag> ./gpu-bench.sh  # same llama.cpp version on every system
#   LABEL=dev ./gpu-bench.sh        # name for this system in the results (default: hostname)
#   RESULTS=/some/dir ./gpu-bench.sh  # where the results go (default: $WORK/results)
#
# Needs: git, cmake, a C++ compiler, curl, python3, and the headers/tools for the backend.
# On Ubuntu, for Vulkan:
#   sudo apt install build-essential cmake git curl python3 libvulkan-dev glslc \
#     spirv-headers mesa-vulkan-drivers vulkan-tools mesa-utils
# On Fedora:
#   sudo dnf install gcc-c++ make cmake git curl python3 vulkan-headers vulkan-loader-devel \
#     glslc spirv-headers-devel mesa-vulkan-drivers vulkan-tools egl-utils
# and add the user to the render group, so it can open /dev/dri/renderD*.
#
# A system without a usable GPU (no device, or only the llvmpipe software renderer) still
# gets the CPU-only run, so it has a baseline. On Linux the OpenGL renderer is recorded
# too, because some virtual GPUs offer OpenGL but not Vulkan. The results are appended to
# $RESULTS/$LABEL.csv.
set -euo pipefail

WORK="${WORK:-$HOME/gpu-bench}"
RESULTS="${RESULTS:-$WORK/results}"
LLAMA_REF="${LLAMA_REF:-master}"
MODEL="${MODEL:-}"
LABEL="${LABEL:-$(uname -n)}"
MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_0.gguf"

if [ -z "${BACKEND:-}" ]; then
  if [ "$(uname -s)" = Darwin ]; then BACKEND=metal; else BACKEND=vulkan; fi
fi
case "$BACKEND" in
  metal)  FLAGS=(-DGGML_METAL=ON) ;;
  vulkan) FLAGS=(-DGGML_VULKAN=ON) ;;
  cuda)   FLAGS=(-DGGML_CUDA=ON) ;;
  hip)    FLAGS=(-DGGML_HIP=ON) ;;
  *) echo "Unknown BACKEND: $BACKEND (metal, vulkan, cuda, hip)" >&2; exit 1 ;;
esac

SRC="$WORK/llama.cpp"
BUILD="$WORK/build-$BACKEND"
mkdir -p "$WORK" "$RESULTS"

if [ ! -d "$SRC/.git" ]; then
  git init -q "$SRC"
  git -C "$SRC" remote add origin https://github.com/ggml-org/llama.cpp
fi
git -C "$SRC" fetch -q --depth 1 origin "$LLAMA_REF"
git -C "$SRC" checkout -q --detach FETCH_HEAD

JOBS="$(getconf _NPROCESSORS_ONLN)"
# A build folder configured for another path (the work folder was moved) can't be reused.
if [ -f "$BUILD/CMakeCache.txt" ] &&
   ! grep -qx "CMAKE_HOME_DIRECTORY:INTERNAL=$SRC" "$BUILD/CMakeCache.txt"; then
  rm -rf "$BUILD"
fi
cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DLLAMA_CURL=OFF "${FLAGS[@]}"
cmake --build "$BUILD" --config Release --target llama-bench -j "$JOBS"
BENCH="$BUILD/bin/llama-bench"

if [ -z "$MODEL" ]; then
  MODEL="$WORK/$(basename "$MODEL_URL")"
  if [ ! -f "$MODEL" ]; then
    curl -fL -o "$MODEL.part" "$MODEL_URL"
    mv "$MODEL.part" "$MODEL"
  fi
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$RESULTS/$LABEL-$BACKEND-$STAMP.txt"
JSONL="$RESULTS/$LABEL-$BACKEND-$STAMP.jsonl"
CSV="$RESULTS/$LABEL.csv"
COMMIT="$(git -C "$SRC" rev-parse --short HEAD)"

# The CPU model, for the results. llama-bench only names it on x86. Some hypervisors,
# such as those on Apple silicon, hide the model from the guest and show only the vendor.
cpu_name() {
  local m v
  if [ "$(uname -s)" = Darwin ]; then
    sysctl -n machdep.cpu.brand_string
    return
  fi
  m="$(LC_ALL=C lscpu 2>/dev/null | sed -n 's/^Model name:[[:space:]]*//p' | head -1)"
  if [ -z "$m" ] || [ "$m" = "-" ]; then
    m="$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -1)"
  fi
  if [ -z "$m" ] || [ "$m" = "-" ]; then
    v="$(LC_ALL=C lscpu 2>/dev/null | sed -n 's/^Vendor ID:[[:space:]]*//p' | head -1)"
    m="${v:-Unknown} CPU, model hidden from the guest"
  fi
  printf '%s\n' "$m"
}
CPU_NAME="$(cpu_name)"
{
  echo "label: $LABEL"
  echo "host: $(uname -srm)"
  echo "backend: $BACKEND"
  echo "llama.cpp: $LLAMA_REF ($COMMIT)"
  echo "model: $(basename "$MODEL")"
  echo "cpu: $CPU_NAME"
  echo "cpus: $JOBS"
  echo
  echo "== Devices =="
  "$BENCH" --list-devices
} 2>&1 | tee "$OUT"

# A device line looks like "  Vulkan0: name (...)". BLAS and CPU entries are not GPUs,
# and llvmpipe is Mesa's software renderer, which runs on the CPU.
GPU_DEVICE="$(grep -E '^[[:space:]]*(Vulkan|CUDA|ROCm|MTL|Metal)[0-9]*:' "$OUT" |
              grep -vi llvmpipe | head -1 | sed 's/^[[:space:]]*//' || true)"
if [ -z "$GPU_DEVICE" ]; then
  if grep -q 'renderD.*Permission denied' "$OUT"; then
    echo "There is a GPU render node, but this user can't open it. Add the user to the render group:" | tee -a "$OUT"
    echo "  sudo usermod -aG render,video \"\$USER\", then log in again." | tee -a "$OUT"
  fi
  if grep -qi llvmpipe "$OUT"; then
    echo "No GPU: only llvmpipe, Mesa's software renderer. Running the CPU-only test." | tee -a "$OUT"
  else
    echo "No $BACKEND GPU device found. Running the CPU-only test." | tee -a "$OUT"
  fi
fi

# OpenGL, through EGL without a display. Needs eglinfo from mesa-utils.
GL_RENDERER=""
if [ "$(uname -s)" = Linux ] && command -v eglinfo >/dev/null; then
  GL_RENDERER="$(eglinfo -B -p surfaceless 2>/dev/null |
                 sed -n 's/^OpenGL core profile renderer: //p; s/^OpenGL renderer string: //p' |
                 head -1 || true)"
  { echo; echo "OpenGL renderer: ${GL_RENDERER:-none}"; } | tee -a "$OUT"
fi

# pp = prompt processing, tg = text generation, both in tokens per second.
ARGS=(-m "$MODEL" -p 512 -n 128 -r 3 -o jsonl)

run() {
  local mode=$1; shift
  echo; echo "== $mode =="
  "$BENCH" "${ARGS[@]}" "$@" | while IFS= read -r line; do
    printf '{"mode":"%s",%s\n' "$mode" "${line#\{}" >>"$JSONL"
    printf '%s\n' "$line"
  done
}
if [ -n "$GPU_DEVICE" ]; then
  run gpu -ngl 99 2>&1 | tee -a "$OUT"
fi
run cpu -dev none -ngl 0 2>&1 | tee -a "$OUT"

# Append to $LABEL.csv and print a summary.
python3 - "$JSONL" "$CSV" "$LABEL" "$BACKEND" "$LLAMA_REF" "$COMMIT" "$(basename "$MODEL")" \
  "${GPU_DEVICE:-none}" "$(uname -srm)" "$GL_RENDERER" "$CPU_NAME" <<'PY' | tee -a "$OUT"
import csv, datetime, json, os, sys

jsonl, out, label, backend, ref, commit, model, device, host, gl, cpu = sys.argv[1:]
run_at = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
fields = ["run_at", "label", "host", "backend", "llama_ref", "llama_commit", "model",
          "mode", "device", "threads", "test", "tokens_per_s", "stddev"]
new = not os.path.exists(out) or os.path.getsize(out) == 0
base = {"run_at": run_at, "label": label, "host": host, "backend": backend,
        "llama_ref": ref, "llama_commit": commit, "model": model}
rows = []
with open(jsonl) as f:
    for line in f:
        line = line.strip()
        if not line.startswith("{"):
            continue
        r = json.loads(line)
        test = f"pp{r['n_prompt']}" if r.get("n_prompt") else f"tg{r['n_gen']}"
        rows.append({**base, "mode": r["mode"],
            "device": device if r["mode"] == "gpu" else cpu,
            "threads": r.get("n_threads", ""), "test": test,
            "tokens_per_s": f"{r['avg_ts']:.2f}", "stddev": f"{r['stddev_ts']:.2f}"})
# Not a measurement: which devices this system offers, for the report.
info = [{**base, "mode": "info", "device": device, "test": "gpu",
         "threads": "", "tokens_per_s": "", "stddev": ""}]
if gl:
    info.append({**info[0], "device": gl, "test": "opengl"})
with open(out, "a", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fields)
    if new:
        w.writeheader()
    w.writerows(info + rows)

print()
print(f"### {label}, {backend} ({run_at})")
print()
if gl:
    print(f"OpenGL renderer: {gl}")
    print()
print("| Mode | Device | Test | Tokens/s |")
print("| --- | --- | --- | ---: |")
for r in rows:
    print(f"| {r['mode']} | {r['device']} | {r['test']} | {r['tokens_per_s']} ± {r['stddev']} |")
PY

echo
echo "Saved to $OUT and $CSV"
