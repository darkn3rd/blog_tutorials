#!/bin/sh
# The steps the Makefile runs, for MSYS2 or Git Bash. It matches wsl.ps1: each step is
# called as `wsl.sh <step>` with the Makefile's settings passed as options.
#
# With --dry-run, each command that would change something is printed instead of run.
# Read-only queries, such as listing distros or finding the newest stage3, still run.
set -eu

usage() {
  echo "usage: $0 download|image|create|start|provision|check-config|ssh|status|versions|halt|destroy|purge [options]" >&2
  exit 2
}

[ $# -gt 0 ] || usage
step=$1
shift

NAME=gentoo-dev
MIRROR=https://distfiles.gentoo.org/releases/amd64/autobuilds
FLAVOR=stage3-amd64-systemd
DOWNLOAD=images/stage3-amd64-systemd.tar.xz
IMAGE=images/gentoo-wsl.tar
VM_DIR=.vm
HTTP_PORT=8080
CHECK_CONFIG_URL=https://raw.githubusercontent.com/moby/moby/master/contrib/check-config.sh
DRY_RUN=false

while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift; continue ;;
    --name) NAME=$2 ;;
    --mirror) MIRROR=$2 ;;
    --flavor) FLAVOR=$2 ;;
    --download) DOWNLOAD=$2 ;;
    --image) IMAGE=$2 ;;
    --vm-dir) VM_DIR=$2 ;;
    --http-port) HTTP_PORT=$2 ;;
    --check-config-url) CHECK_CONFIG_URL=$2 ;;
    *) usage ;;
  esac
  shift 2
done

cd "$(dirname "$0")"

# How long `make start` waits for systemd to finish booting.
BOOT_TIMEOUT=300

# MSYS2 rewrites arguments that look like Unix paths, such as `--cd /workspace`, before
# it runs a Windows program. wsl.exe needs them as they are.
export MSYS2_ARG_CONV_EXCL='*'
# Without this, wsl.exe writes its own messages and listings in UTF-16.
export WSL_UTF8=1

# Windows' bsdtar, which reads mtree files and other archives as input.
TAR=$(cygpath -S)/tar.exe
# The project folder as Windows sees it, for wsl.exe --cd.
WIN_DIR=$(cygpath -w "$PWD")

# For commands that change something: prints them instead under --dry-run.
run() {
  if [ "$DRY_RUN" = true ]; then
    echo "What if: $*"
  else
    "$@"
  fi
}

# wsl.exe ends lines with CRLF, and some of its messages ignore WSL_UTF8.
clean() { tr -d '\r\0'; }

distros() { wsl.exe --list --quiet "$@" 2>/dev/null | clean || true; }

state() {
  if ! distros | grep -qx "$NAME"; then
    echo 'not created'
  elif distros --running | grep -qx "$NAME"; then
    echo running
  else
    echo stopped
  fi
}

# Steps write to <file>.part and rename it when done, so make never sees half a file.
save_url() {
  run curl -fL --progress-bar -o "$2.part" "$1"
  run mv -f "$2.part" "$2"
}

case $step in
  download)
    # The latest-*.txt file names the newest build: "<dir>/<file> <size>".
    path=$(curl -fsSL "$MIRROR/latest-$FLAVOR.txt" |
      sed -n "s|^\([^ ]*/$FLAVOR-[^ ]*\.tar\.xz\) .*|\1|p" | head -n 1)
    [ -n "$path" ] || { echo "No $FLAVOR tarball listed in $MIRROR/latest-$FLAVOR.txt" >&2; exit 1; }
    url=$MIRROR/$path
    expected=$(curl -fsSL "$url.sha256" | sed -n 's/^\([0-9a-f]\{64\}\) .*/\1/p' | head -n 1)
    [ -n "$expected" ] || { echo "No SHA256 in $url.sha256" >&2; exit 1; }

    run mkdir -p "$(dirname "$DOWNLOAD")"
    echo "Downloading $url"
    save_url "$url" "$DOWNLOAD"
    if [ "$DRY_RUN" = true ]; then
      echo "What if: check the SHA256 is $expected"
      exit 0
    fi
    actual=$(sha256sum "$DOWNLOAD" | cut -d' ' -f1)
    if [ "$actual" != "$expected" ]; then
      rm -f "$DOWNLOAD"
      echo "SHA256 mismatch: expected $expected, got $actual" >&2
      exit 1
    fi
    echo "SHA256 OK"
    ;;

  image)
    # Copies every entry of the stage3, keeping its owners and modes, then adds the
    # entries listed in image.mtree with the owners and modes given there.
    run "$TAR" -cf "$IMAGE.part" "@$DOWNLOAD" @image.mtree
    run mv -f "$IMAGE.part" "$IMAGE"
    ;;

  create)
    run mkdir -p "$VM_DIR"
    run wsl.exe --import "$NAME" "$VM_DIR" "$IMAGE" --version 2
    if ! run wsl.exe -d "$NAME" -u root --cd "$WIN_DIR" -- sh guest/setup.sh; then
      # Leave nothing half-made, so the next `make` creates the machine again.
      wsl.exe --unregister "$NAME" >/dev/null
      exit 1
    fi
    ;;

  start)
    # WSL stops a distro soon after its last wsl.exe session ends, which would take
    # nginx with it, so a background session that only sleeps keeps it running.
    # Only a running distro is asked, since asking would start a stopped one.
    kept=false
    if [ "$(state)" = running ] &&
      wsl.exe -d "$NAME" -u root -- pgrep -xf 'sleep infinity' >/dev/null; then
      kept=true
    fi
    if [ "$kept" = false ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "What if: wsl.exe -d $NAME -u root --exec sleep infinity, in the background"
      else
        # Its output goes nowhere, so make doesn't wait on it.
        nohup wsl.exe -d "$NAME" -u root --exec sleep infinity </dev/null >/dev/null 2>&1 &
      fi
    fi

    if [ "$DRY_RUN" = true ]; then
      echo "What if: wsl.exe -d $NAME -u root -- timeout $BOOT_TIMEOUT systemctl is-system-running --wait"
      exit 0
    fi
    echo 'Waiting for systemd...'
    status=$(wsl.exe -d "$NAME" -u root -- timeout "$BOOT_TIMEOUT" \
      systemctl is-system-running --wait | clean) || true
    case $status in
      running) ;;
      degraded) echo "systemd is degraded; run 'systemctl --failed' in the guest to see why." ;;
      *)
        wsl.exe -d "$NAME" -u root -- systemctl list-jobs --no-pager || true
        echo "systemd did not finish booting within ${BOOT_TIMEOUT}s (state: '$status')" >&2
        exit 1
        ;;
    esac
    ;;

  provision)
    run wsl.exe -d "$NAME" -u root --cd "$WIN_DIR" -- sh guest/install-ansible.sh
    run wsl.exe -d "$NAME" --cd /workspace -- \
      ansible-playbook -e "http_port=$HTTP_PORT" playbook.yaml
    ;;

  check-config)
    # Docker's script reads the kernel config from /proc/config.gz, which the WSL
    # kernel provides, so it checks the kernel every WSL distro shares.
    save_url "$CHECK_CONFIG_URL" check-config.sh
    run wsl.exe -d "$NAME" --cd /workspace -- bash ./check-config.sh
    ;;

  ssh)
    run wsl.exe -d "$NAME" --cd /workspace
    ;;

  status)
    s=$(state)
    [ "$s" != running ] || s="$s, http://localhost:$HTTP_PORT"
    echo "$s"
    ;;

  versions)
    windows=$(cmd.exe /c ver | clean | sed -n 's/.*Version \([0-9.]*\).*/\1/p')
    wsl=$(wsl.exe --version | clean | sed -n 's/^WSL[^:]*: *//p' | head -n 1)
    make=$(make --version | head -n 1 | sed 's/^GNU Make //')
    ansible='not installed'
    if [ "$(state)" != 'not created' ]; then
      out=$(wsl.exe -d "$NAME" -- sh -c 'ansible --version 2>/dev/null | head -n 1' | clean)
      [ -z "$out" ] || ansible=$(echo "$out" | sed 's/.*\[core \([^]]*\)\].*/\1/')
    fi
    printf '%-14s%s\n' Windows: "$windows" WSL: "$wsl" make: "$make" ansible-core: "$ansible"
    ;;

  halt)
    [ "$(state)" != running ] || run wsl.exe --terminate "$NAME"
    ;;

  destroy)
    [ "$(state)" = 'not created' ] || run wsl.exe --unregister "$NAME"
    [ ! -e "$VM_DIR" ] || run rm -rf "$VM_DIR"
    ;;

  purge)
    dir=$(dirname "$DOWNLOAD")
    if [ -e "$dir" ]; then run rm -rf "$dir"; else echo 'No downloaded image to remove.'; fi
    ;;

  *) usage ;;
esac
