#!/usr/bin/env bash
set -uo pipefail

# Walks the 4 demos (Service/NLB, Ingress/ALB, Gateway+TCPRoute/NLB, Gateway+HTTPRoute/ALB),
# fetches each one's external address, waits for DNS, and curls it. Bounded timeouts:
# if the AWS resource never provisions or DNS never propagates, that demo is reported FAIL
# instead of hanging forever.
#
# Works against either demos/tf (Terraform) or demos/cli (create_demos.sh) - both produce
# the same namespaces/resource names. Table below mirrors those defaults; if you override
# the namespaces or names in either one, update this table to match.

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"
POLL_INTERVAL="${POLL_INTERVAL:-10}"

for bin in kubectl dig curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Required tool '$bin' not found in PATH." >&2
    exit 1
  fi
done

# name | namespace | kind (service|ingress|gateway) | resource name | Host header (empty = none)
DEMOS=(
  "Service/NLB|demo-nlb|service|demo-nlb-app|"
  "Ingress/ALB|demo-alb|ingress|demo-alb-app|demo.example.com"
  "Gateway+TCPRoute/NLB|demo-gwtcp|gateway|demo-gwtcp-app-gateway|"
  "Gateway+HTTPRoute/ALB|demo-gwhttp|gateway|demo-gwhttp-app-gw|demo.example.com"
)

pass=0
fail=0

# Polls `"$@"` until it prints a non-empty value or TIMEOUT_SECONDS elapses.
# Prints a "." to stderr per attempt so a long wait doesn't look like a hang.
wait_for() {
  local elapsed=0 value=""

  while (( elapsed < TIMEOUT_SECONDS )); do
    value="$("$@" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      echo >&2
      printf '%s' "$value"
      return
    fi
    printf '.' >&2
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done
  echo >&2
}

for demo in "${DEMOS[@]}"; do
  IFS='|' read -r name namespace kind resource host <<< "$demo"

  echo
  echo "===== ${name} (namespace: ${namespace}) ====="

  case "$kind" in
    service | ingress)
      jsonpath='{.status.loadBalancer.ingress[0].hostname}'
      ;;
    gateway)
      jsonpath='{.status.addresses[0].value}'
      ;;
    *)
      echo "Unknown kind '${kind}' for ${name}" >&2
      exit 1
      ;;
  esac

  echo "Waiting up to ${TIMEOUT_SECONDS}s for ${kind}/${resource} to be provisioned..."
  address=$(wait_for kubectl get "$kind" "$resource" -n "$namespace" -o jsonpath="$jsonpath")

  if [ -z "$address" ]; then
    echo "❌ FAIL: ${name} - no address/hostname after ${TIMEOUT_SECONDS}s (not provisioned)"
    fail=$((fail + 1))
    continue
  fi
  echo "address: ${address}"

  echo "Waiting up to ${TIMEOUT_SECONDS}s for DNS to resolve ${address}..."
  resolved=$(wait_for dig +short "$address")

  if [ -z "$resolved" ]; then
    echo "❌ FAIL: ${name} - DNS for ${address} never resolved after ${TIMEOUT_SECONDS}s"
    fail=$((fail + 1))
    continue
  fi
  echo "DNS resolved: ${resolved}"

  curl_args=(-s -o /dev/null -w "%{http_code}" --max-time 10)
  if [ -n "$host" ]; then
    curl_args+=(-H "Host: ${host}")
  fi
  curl_args+=("http://${address}")

  # curl's own -w already prints "000" on connection failure/timeout - no
  # extra fallback needed (and one caused this to double up into "000000")
  http_code=$(curl "${curl_args[@]}" 2>/dev/null)

  if [[ "$http_code" =~ ^2 ]]; then
    echo "✅ PASS: ${name} - HTTP ${http_code}"
    pass=$((pass + 1))
  else
    echo "❌ FAIL: ${name} - HTTP ${http_code}"
    fail=$((fail + 1))
  fi
done

echo
echo "===== Summary: ${pass} passed, ${fail} failed ====="

[ "$fail" -eq 0 ]
