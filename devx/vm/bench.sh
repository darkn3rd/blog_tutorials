#!/usr/bin/env bash
# Time the same VM lifecycle in any project that has make targets up, provision, halt,
# destroy and purge, plus site/index.html. Run it from the project folder:
#
#   cd devx/vm/vagrant/virtualbox/ansible
#   ../../../bench.sh
#
# By default the VM image or box must already be downloaded. With --cold, the script
# deletes the cached image with `make purge` and times one extra `make up` that includes
# the download, then destroys the VM and runs the usual steps, so
# download time ≈ cold up - warm up.
#
# Results print as a Markdown table and are appended to timings.csv next to this script.
set -uo pipefail

cold=false
[ "${1:-}" = --cold ] && cold=true

project=$(basename "$(dirname "$PWD")")/$(basename "$PWD")
csv=$(cd "$(dirname "$0")" && pwd)/timings.csv
log=$(mktemp)
page=site/index.html
backup=$(mktemp)
run_at=$(date '+%Y-%m-%d %H:%M')

cp "$page" "$backup"
trap 'cp "$backup" "$page"; rm -f "$log" "$backup"' EXIT

now() { perl -MTime::HiRes=time -e 'printf "%.3f", time'; }

rows=()
step() {
  local label=$1; shift
  printf '%-40s' "$label" >&2
  local start end secs
  start=$(now)
  if ! "$@" >"$log" 2>&1; then
    echo " FAILED" >&2
    tail -20 "$log" >&2
    exit 1
  fi
  end=$(now)
  secs=$(echo "$end - $start" | bc)
  local recap
  recap=$(grep -oE 'changed=[0-9]+' "$log" | tail -1)
  printf ' %6.1fs %s\n' "$secs" "$recap" >&2
  rows+=("$label|$secs|$recap")
  last=$secs
  [ -f "$csv" ] || echo "run_at,project,step,seconds,result" >"$csv"
  echo "$run_at,$project,\"$label\",$secs,$recap" >>"$csv"
}

if lsof -nP -iTCP:8080 -sTCP:LISTEN >/dev/null && ! make -s status 2>/dev/null | grep -qiE 'running'; then
  echo "Port 8080 is in use by something else:" >&2
  lsof -nP -iTCP:8080 -sTCP:LISTEN >&2
  exit 1
fi

echo "Resetting: make destroy" >&2
make destroy >/dev/null 2>&1

if $cold; then
  echo "Deleting the cached image: make purge" >&2
  if ! make purge >"$log" 2>&1; then
    cat "$log" >&2
    exit 1
  fi
  step "up, download, create and provision" make up PROVISION=true
  cold_secs=$last
  echo "Resetting: make destroy" >&2
  make destroy >/dev/null 2>&1
fi

step "up, create and provision"         make up PROVISION=true
warm_secs=$last
step "provision, no changes"            make provision
perl -pi -e 's#</h1>#!</h1>#' "$page"
step "provision, page changed"          make provision
cp "$backup" "$page"
if make -n playbook >/dev/null 2>&1; then
  step "playbook, page restored"        make playbook
  step "playbook, no changes"           make playbook
else
  step "provision, page restored"       make provision
fi
step "halt"                             make halt
step "up, from stopped"                 make up
step "up, while running"                make up
step "destroy"                          make destroy

echo
echo "### $project ($run_at)"
echo
echo "| Step | Seconds | Ansible |"
echo "| --- | ---: | --- |"
for r in "${rows[@]}"; do
  IFS='|' read -r label secs recap <<<"$r"
  printf '| %s | %.1f | %s |\n' "$label" "$secs" "$recap"
done
if $cold; then
  download=$(echo "$cold_secs - $warm_secs" | bc)
  printf '\nDownload, estimated as cold up minus warm up: %.1fs\n' "$download"
  echo "$run_at,$project,\"download (estimated)\",$download," >>"$csv"
fi
