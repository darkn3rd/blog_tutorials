# Shared by gpu-bench-all.sh and hwinfo-all.sh: names this machine's platform and
# describes it. Source it; it sets os, arch and platform.

# The OS (the distribution on Linux) and the CPU architecture, such as ubuntu-x86_64.
platform_os() {
  case $(uname -s) in
    Darwin) echo macos ;;
    Linux) (. /etc/os-release 2>/dev/null; echo "${ID:-linux}") ;;
    MINGW* | MSYS* | CYGWIN*) echo windows ;;
    *) uname -s | tr '[:upper:]' '[:lower:]' ;;
  esac
}
platform_arch() {
  case $(uname -m) in
    arm64 | aarch64) echo arm64 ;;
    x86_64 | amd64) echo x86_64 ;;
    *) uname -m ;;
  esac
}
os=$(platform_os)
arch=$(platform_arch)
platform=$os-$arch

# A project runs here if it lists this platform, or linux-<arch> on any Linux.
runs_here() {
  local p
  for p in $1; do
    [ "$p" = "$platform" ] && return 0
    case $os in macos | windows) ;; *) [ "$p" = "linux-$arch" ] && return 0 ;; esac
  done
  return 1
}

# One "key: value" line each for the OS, model, CPU, GPU and memory of this machine.
describe_machine() {
  case $(uname -s) in
    Darwin)
      echo "os: macOS $(sw_vers -productVersion)"
      echo "model: $(sysctl -n hw.model)"
      echo "cpu: $(sysctl -n machdep.cpu.brand_string)"
      echo "gpu: $(system_profiler SPDisplaysDataType 2>/dev/null |
                    sed -n 's/^ *Chipset Model: //p' | paste -sd, - | sed 's/,/, /g')"
      echo "memory: $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
      ;;
    Linux)
      echo "os: $(. /etc/os-release; echo "$PRETTY_NAME"), kernel $(uname -r)"
      echo "model: $(cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name 2>/dev/null | paste -sd' ' -)"
      echo "cpu: $(LC_ALL=C lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -1)"
      echo "gpu: $(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/^[^ ]* [^:]*: //' |
                    paste -sd, - | sed 's/,/, /g')"
      echo "memory: $(awk '/^MemTotal:/ { printf "%d GB", $2 / 1048576 + 0.5 }' /proc/meminfo)"
      ;;
  esac
}
