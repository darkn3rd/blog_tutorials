#!/usr/bin/env bash
# Boots a freshly built box with Vagrant and checks it runs the expected architecture.
#
#   bin/smoke-test.sh <box-file> <arch>
set -euo pipefail

box=$(cd "$(dirname "${1:?box file}")" && pwd)/$(basename "$1")
arch=${2:?arch}
name="ubuntu-smoke-$arch"

case "$arch" in
  amd64) expected=x86_64 ;;
  arm64) expected=aarch64 ;;
  *) echo "ERROR: unknown arch $arch" >&2; exit 1 ;;
esac

# A fresh directory, so a Vagrantfile higher up the tree can't interfere
work=$(mktemp -d)
cleanup() {
  (cd "$work" && vagrant destroy -f) >/dev/null 2>&1 || true
  vagrant box remove "$name" --all --force >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

vagrant box add --force --name "$name" --provider virtualbox --architecture "$arch" "$box"

cd "$work"
vagrant init "$name"
vagrant up --provider virtualbox
actual=$(vagrant ssh -c 'uname -m' | tr -d '\r')
vagrant ssh -c 'lsb_release -ds'

if [[ "$actual" != "$expected" ]]; then
  echo "ERROR: box reports $actual, expected $expected" >&2
  exit 1
fi
echo "Smoke test passed ($arch)"
