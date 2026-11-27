#!/usr/bin/env bash
# Check that a system has what a GPU in a VM needs, in the style of Docker's
# check-config.sh. It works out where it runs and checks that:
#
#   Linux guest   the kernel options, the GPU driver, the virtio-gpu features the host
#                 and the guest agreed on (blob_alignment among them), the device nodes
#                 and their permissions, and the Mesa drivers for OpenGL and Vulkan
#   Linux host    KVM, the host GPU and its render node, udmabuf, virglrenderer, QEMU's
#                 OpenGL devices, the IOMMU and vfio-pci for passthrough, and GVT-g
#   macOS host    Apple silicon, krunkit and MoltenVK, and whether QEMU has OpenGL
#
#   ./gpu-check.sh                 # run as the user that will use the GPU
#   ./gpu-check.sh --guest         # force a mode: --guest, --host
#
# Run it as the user that will use the GPU, not as root, so that the render node check
# is about that user. A few facts (dmesg lines) need root; the script asks sudo for them
# without a password prompt and reports them as unknown if it can't. Nothing is changed.
# It exits 1 if something required is missing, otherwise 0.
set -uo pipefail
export LC_ALL=C

usage() { sed -n '2,18s/^# \{0,1\}//p' "$0"; exit "${1:-0}"; }

mode=""
while [ $# -gt 0 ]; do
  case $1 in
    --guest)   mode=guest ;;
    --host)    mode=host ;;
    -h|--help) usage ;;
    *)         echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
  shift
done

# --- Output --------------------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_ok=$'\033[32m' c_warn=$'\033[33m' c_bad=$'\033[31m' c_dim=$'\033[2m' c_bold=$'\033[1m' c_off=$'\033[0m'
else
  c_ok="" c_warn="" c_bad="" c_dim="" c_bold="" c_off=""
fi
failed=0
warned=0

section() { printf '\n%s%s%s\n' "$c_bold" "$1" "$c_off"; }
# row STATUS NAME VALUE [NOTE]; STATUS is ok, warn, bad or info.
row() {
  local color
  case $1 in
    ok)   color=$c_ok ;;
    warn) color=$c_warn; warned=$((warned + 1)) ;;
    bad)  color=$c_bad;  failed=$((failed + 1)) ;;
    *)    color=$c_dim ;;
  esac
  printf -- '- %s: %s%s%s\n' "$2" "$color" "$3" "$c_off"
  [ -n "${4:-}" ] && printf '    %s%s%s\n' "$c_dim" "$4" "$c_off"
  return 0
}

have() { command -v "$1" >/dev/null 2>&1; }

# dmesg, as root if that is possible without a password.
dmesg_text() {
  if [ -z "${_dmesg+x}" ]; then
    _dmesg=$(dmesg 2>/dev/null || sudo -n dmesg 2>/dev/null || true)
  fi
  printf '%s' "$_dmesg"
}

# --- Kernel options ------------------------------------------------------------------

# The kernel's build options, from the first of these that exists.
find_kconfig() {
  local f
  for f in /proc/config.gz "/boot/config-$(uname -r)" "/lib/modules/$(uname -r)/config"; do
    [ -r "$f" ] && { echo "$f"; return; }
  done
}

# kopt LEVEL OPTION WHAT: LEVEL is required (missing is bad) or optional (missing is info).
kopt() {
  local level=$1 opt=$2 what=$3 v
  v=$(printf '%s\n' "$kconfig" | sed -n "s/^CONFIG_${opt}=//p")
  case $v in
    y) row ok   "CONFIG_$opt" "enabled" "$what" ;;
    m) row ok   "CONFIG_$opt" "enabled (module)" "$what" ;;
    *) if [ "$level" = required ]; then row bad "CONFIG_$opt" "missing" "$what"
       else row info "CONFIG_$opt" "missing" "$what"; fi ;;
  esac
}

check_kernel_options() {
  section "Kernel options"
  kconfig_file=$(find_kconfig)
  case $kconfig_file in
    *.gz) kconfig=$(gzip -dc "$kconfig_file") ;;
    ?*)   kconfig=$(cat "$kconfig_file") ;;
    *)    kconfig="" ;;
  esac
  if [ -z "$kconfig" ]; then
    row info "Kernel config" "not found" "Looked in /proc/config.gz, /boot/config-$(uname -r) and /lib/modules; skipping these checks"
    return
  fi
  printf '  %sfrom %s%s\n' "$c_dim" "$kconfig_file" "$c_off"
  local spec
  for spec in "$@"; do
    # shellcheck disable=SC2086
    kopt ${spec%%:*} "$(cut -d: -f2 <<<"$spec")" "$(cut -d: -f3- <<<"$spec")"
  done
}

# --- Linux guest ---------------------------------------------------------------------

# The negotiated virtio-gpu features: a string of 0s and 1s, bit N at position N+1.
# The bits are from include/uapi/linux/virtio_gpu.h.
feature_bit() { [ "${features:$1:1}" = 1 ]; }

# Whether this kernel's virtio-gpu driver knows blob_alignment, even if the host doesn't
# offer it: the driver prints the feature's name, so look for it in the module.
driver_knows_blob_alignment() {
  local ko
  dmesg_text | grep -q 'blob_alignment' && return 0
  ko=$(modinfo -n virtio_gpu 2>/dev/null) || return 2
  [ -r "$ko" ] || return 2
  case $ko in
    *.ko.zst) have zstd || return 2; zstd -dc "$ko" ;;
    *.ko.xz)  have xz   || return 2; xz -dc "$ko" ;;
    *.ko.gz)  gzip -dc "$ko" ;;
    *.ko)     cat "$ko" ;;
    *)        return 2 ;;
  esac 2>/dev/null | grep -aq 'blob_alignment'
}

check_guest() {
  local arch pagesize virt
  arch=$(uname -m)
  pagesize=$(getconf PAGESIZE 2>/dev/null || echo 0)
  virt=$(systemd-detect-virt 2>/dev/null || true)
  . /etc/os-release 2>/dev/null || true

  section "System"
  row info "OS" "${PRETTY_NAME:-unknown}"
  row info "Kernel" "$(uname -r), $arch, $((pagesize / 1024)) KiB pages"
  row info "Virtualization" "${virt:-unknown}"

  check_kernel_options \
    "required:DRM:Direct Rendering Manager, the kernel side of every GPU driver" \
    "required:DRM_VIRTIO_GPU:The virtio-gpu driver, for virgl, Venus and the 2D display" \
    "optional:VIRTIO_PCI:virtio over PCI, used by QEMU and libvirt" \
    "optional:VIRTIO_MMIO:virtio over MMIO, used by krunkit and other microVMs" \
    "required:DMA_SHARED_BUFFER:dma-buf, to share GPU buffers between drivers and Mesa" \
    "required:SYNC_FILE:Fences that Mesa waits on for GPU work" \
    "optional:DRM_I915:Intel GPUs, for passthrough" \
    "optional:DRM_XE:Newer Intel GPUs, for passthrough" \
    "optional:DRM_AMDGPU:AMD GPUs, for passthrough" \
    "optional:DRM_NOUVEAU:NVIDIA GPUs with the open driver, for passthrough"

  # --- GPU devices ---
  section "GPU devices"
  local found=0 dev name driver
  # virtio-gpu, on PCI or MMIO: virtio device ID 16.
  virtio_gpu=""
  for dev in /sys/bus/virtio/devices/virtio*; do
    [ "$(cat "$dev/device" 2>/dev/null)" = 0x0010 ] || continue
    virtio_gpu=$dev; found=1
    driver=$(basename "$(readlink -f "$dev/driver" 2>/dev/null)" 2>/dev/null)
    if [ "$driver" = virtio_gpu ]; then
      row ok "virtio-gpu" "${dev##*/} on $(basename "$(dirname "$(readlink -f "$dev")")"), driver virtio_gpu"
    else
      row bad "virtio-gpu" "${dev##*/}, no driver bound" "Load it with: sudo modprobe virtio_gpu"
    fi
  done
  # Other GPUs, which in a VM means passthrough or an emulated display adapter.
  if have lspci; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case $line in *Virtio*|*virtio*) continue ;; esac
      found=1
      slot=${line%% *}
      driver=$(basename "$(readlink -f "/sys/bus/pci/devices/0000:$slot/driver" 2>/dev/null)" 2>/dev/null)
      name=${line#* }
      case $line in
        *NVIDIA*|*AMD*|*ATI*|*Intel*)
          if [ -n "$driver" ]; then row ok "PCI $slot" "$name, driver $driver"
          else row bad "PCI $slot" "$name, no driver bound" "Install or load the vendor's driver"; fi ;;
        *)
          row info "PCI $slot" "$name${driver:+, driver $driver}" "An emulated display adapter, without 3D" ;;
      esac
    done < <(lspci -mm 2>/dev/null | awk -F'"' '$2 ~ /VGA|3D|Display/ { sub(/ +$/, "", $1); print $1 " " $4 " " $6 }')
  fi
  [ $found = 1 ] || row bad "GPU" "none found" "The VM has no GPU device, or its driver isn't loaded"

  # --- Device nodes ---
  section "Device nodes"
  local node
  if ! ls /dev/dri/renderD* >/dev/null 2>&1; then
    row bad "/dev/dri/renderD*" "missing" "No render node: Mesa can't use a GPU without one"
  fi
  for node in /dev/dri/card* /dev/dri/renderD*; do
    [ -e "$node" ] || continue
    local grp
    grp=$(stat -c %G "$node" 2>/dev/null)
    if [ -r "$node" ] && [ -w "$node" ]; then
      row ok "$node" "you can open it (group $grp)"
    elif [[ $node == */renderD* ]]; then
      row bad "$node" "you can't open it (group $grp)" "Add yourself to it: sudo usermod -aG $grp $USER, then log in again"
    else
      row info "$node" "you can't open it (group $grp)" "Only needed for a display; the render node is enough for compute"
    fi
  done

  # --- virtio-gpu features ---
  if [ -n "$virtio_gpu" ]; then
    section "virtio-gpu features (agreed by the host and this kernel)"
    features=$(cat "$virtio_gpu/features" 2>/dev/null)
    local f
    feature_bit 0 && f=yes || f=no
    row "$([ $f = yes ] && echo ok || echo info)" "virgl" "$f" "3D commands to the host; virgl (OpenGL) and Venus (Vulkan) both need it"
    feature_bit 3 && f=yes || f=no
    row "$([ $f = yes ] && echo ok || echo info)" "resource_blob" "$f" "Buffers shared with the host instead of copied; Venus needs it"
    feature_bit 4 && f=yes || f=no
    row "$([ $f = yes ] && echo ok || echo info)" "context_init" "$f" "Contexts of a chosen type, such as Venus; Venus needs it"

    local hv
    hv=$(dmesg_text | sed -n 's/.*\[drm\] features:.*\([+-]\)host_visible.*/\1/p' | tail -1)
    case $hv in
      +) row ok   "host_visible" "yes" "A region of host memory the guest maps; Venus needs it" ;;
      -) row info "host_visible" "no" "A region of host memory the guest maps; Venus needs it" ;;
      *) row info "host_visible" "unknown" "Read from dmesg, which needs root: run with sudo rights" ;;
    esac

    # blob_alignment: the host tells the guest how to align shared buffers. It matters when
    # the host maps memory in larger pages than the guest, as on Apple silicon (16 KiB)
    # with a 4 KiB guest: without it, Vulkan fails with ERROR_OUT_OF_HOST_MEMORY.
    local note="The host's alignment for shared buffers; Venus needs it when host pages are larger than the guest's, as on Apple silicon"
    if feature_bit 5; then
      row ok "blob_alignment" "yes" "$note"
    else
      driver_knows_blob_alignment; case $? in
        0) row info "blob_alignment" "no, this kernel supports it but the host doesn't offer it" "$note" ;;
        1) if [ "$arch" = aarch64 ] && feature_bit 3; then
             row warn "blob_alignment" "no, this kernel doesn't support it" "$note. Use a newer kernel if Vulkan fails with ERROR_OUT_OF_HOST_MEMORY"
           else
             row info "blob_alignment" "no, this kernel doesn't support it" "$note"
           fi ;;
        *) row info "blob_alignment" "no, and unknown whether this kernel supports it" "$note" ;;
      esac
    fi
  fi

  # --- Userspace ---
  section "Mesa and the graphics APIs"
  local mesa=""
  if have rpm; then mesa=$(rpm -q --qf '%{VERSION}' mesa-vulkan-drivers 2>/dev/null || rpm -q --qf '%{VERSION}' mesa-dri-drivers 2>/dev/null)
  elif have dpkg-query; then mesa=$(dpkg-query -W -f '${Version}' mesa-vulkan-drivers 2>/dev/null || dpkg-query -W -f '${Version}' libgl1-mesa-dri 2>/dev/null)
  fi
  case $mesa in *"not installed"*|"") row warn "Mesa" "not found" "Install mesa-vulkan-drivers (Fedora, Debian, Ubuntu)" ;;
                *) row info "Mesa" "$mesa" ;; esac

  local icd
  icd=$(ls /usr/share/vulkan/icd.d/virtio_icd*.json 2>/dev/null | head -1)
  if [ -n "$icd" ]; then row ok "Venus Vulkan driver" "$icd"
  elif [ -n "$virtio_gpu" ]; then row warn "Venus Vulkan driver" "not installed" "Mesa's virtio_icd, in mesa-vulkan-drivers"
  else row info "Venus Vulkan driver" "not installed"; fi

  local vk gpu_vk=""
  if have vulkaninfo; then
    vk=$(vulkaninfo --summary 2>/dev/null | awk -F'= ' '
          /^[[:space:]]*deviceName/ { name = $2 }
          /^[[:space:]]*driverName/ { print name " (" $2 ")" }')
    if [ -z "$vk" ]; then
      row bad "Vulkan devices" "none" "vulkaninfo found no device; see vulkaninfo --summary"
    else
      while IFS= read -r line; do
        case $line in
          *llvmpipe*) row info "Vulkan device" "$line" "Mesa's software renderer, on the CPU" ;;
          *) row ok "Vulkan device" "$line"; gpu_vk=1 ;;
        esac
      done <<<"$vk"
      [ -n "$gpu_vk" ] || row warn "Vulkan on a GPU" "no" "Only the CPU renderer: check the features and drivers above"
    fi
  else
    row info "Vulkan devices" "unknown" "Install vulkan-tools for vulkaninfo"
  fi

  local gl
  if have eglinfo; then
    gl=$(eglinfo -B -p surfaceless 2>/dev/null |
         sed -n 's/^OpenGL core profile renderer: //p; s/^OpenGL renderer string: //p' | head -1)
    case $gl in
      "")         row info "OpenGL renderer" "none" ;;
      *llvmpipe*) row info "OpenGL renderer" "$gl" "Mesa's software renderer, on the CPU; virgl would show virgl here" ;;
      *)          row ok   "OpenGL renderer" "$gl" ;;
    esac
  else
    row info "OpenGL renderer" "unknown" "Install mesa-utils (Debian, Ubuntu) or egl-utils (Fedora) for eglinfo"
  fi
}

# --- Linux host ----------------------------------------------------------------------

check_linux_host() {
  . /etc/os-release 2>/dev/null || true
  section "System"
  row info "OS" "${PRETTY_NAME:-unknown}"
  row info "Kernel" "$(uname -r), $(uname -m)"

  check_kernel_options \
    "required:KVM:Hardware virtualization" \
    "required:DRM:Direct Rendering Manager, the kernel side of every GPU driver" \
    "optional:UDMABUF:Turns guest memory into dma-bufs; QEMU's virtio-gpu blob resources use it" \
    "optional:VFIO_PCI:Hands a PCI device to a VM, for passthrough" \
    "optional:INTEL_IOMMU:Intel's IOMMU, for passthrough" \
    "optional:AMD_IOMMU:AMD's IOMMU, for passthrough" \
    "optional:DRM_I915_GVT_KVMGT:Intel GVT-g, which splits an Intel GPU into virtual ones"

  section "Virtualization"
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then row ok "/dev/kvm" "you can open it"
  elif [ -e /dev/kvm ]; then row bad "/dev/kvm" "you can't open it" "Add yourself to the kvm group: sudo usermod -aG kvm $USER"
  else row bad "/dev/kvm" "missing" "Turn on virtualization in the firmware settings, and load kvm_intel or kvm_amd"; fi
  if [ -e /dev/udmabuf ]; then row ok "/dev/udmabuf" "present"
  else row info "/dev/udmabuf" "missing" "Load it with: sudo modprobe udmabuf"; fi

  section "Host GPUs"
  local line slot driver node
  if have lspci; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      slot=${line%% *}
      driver=$(basename "$(readlink -f "/sys/bus/pci/devices/0000:$slot/driver" 2>/dev/null)" 2>/dev/null)
      node=$(ls "/sys/bus/pci/devices/0000:$slot/drm" 2>/dev/null | grep renderD | head -1)
      if [ "$driver" = vfio-pci ]; then
        row ok "PCI $slot" "${line#* }, bound to vfio-pci" "Ready for passthrough; the host can't use it"
      elif [ -n "$driver" ]; then
        row ok "PCI $slot" "${line#* }, driver $driver${node:+, /dev/dri/$node}"
      else
        row warn "PCI $slot" "${line#* }, no driver bound"
      fi
    done < <(lspci -mm 2>/dev/null | awk -F'"' '$2 ~ /VGA|3D|Display/ { sub(/ +$/, "", $1); print $1 " " $4 " " $6 }')
  else
    row info "Host GPUs" "unknown" "Install pciutils for lspci"
  fi
  local n
  for n in /dev/dri/renderD*; do
    [ -e "$n" ] || { row bad "/dev/dri/renderD*" "missing" "virgl and Venus render on a host render node"; break; }
    if [ -r "$n" ] && [ -w "$n" ]; then row ok "$n" "you can open it"
    else row warn "$n" "you can't open it (group $(stat -c %G "$n"))" "QEMU run as you needs it; libvirt sets its own access"; fi
  done

  section "virglrenderer and QEMU"
  local virgl=""
  virgl=$(ldconfig -p 2>/dev/null | awk '/libvirglrenderer\.so/ { print $NF; exit }')
  if [ -n "$virgl" ]; then
    local ver
    ver=$(pkg-config --modversion virglrenderer 2>/dev/null ||
          dpkg-query -W -f '${Version}' 'libvirglrenderer1*' 2>/dev/null ||
          rpm -q --qf '%{VERSION}' virglrenderer 2>/dev/null || true)
    row ok "virglrenderer" "${ver:-installed} ($virgl)" "Venus needs 1.0 or later, built with Venus"
  else
    row bad "virglrenderer" "not found" "Install libvirglrenderer1 (Debian, Ubuntu) or virglrenderer (Fedora)"
  fi
  local qemu
  qemu=$(command -v qemu-system-x86_64 || command -v qemu-system-aarch64 || true)
  if [ -n "$qemu" ]; then
    local devs
    devs=$("$qemu" -device help 2>/dev/null)
    for d in virtio-vga-gl virtio-gpu-gl-pci; do
      if grep -q "\"$d\"" <<<"$devs"; then row ok "QEMU $d" "available"
      else row warn "QEMU $d" "missing" "QEMU's OpenGL module: qemu-system-modules-opengl (Debian, Ubuntu) or qemu-ui-opengl (Fedora)"; fi
    done
  else
    row info "QEMU" "not installed"
  fi

  section "Passthrough"
  if grep -qwE 'intel_iommu=on|amd_iommu=on|iommu=pt' /proc/cmdline; then
    row ok "IOMMU on the kernel command line" "$(grep -owE 'intel_iommu=on|amd_iommu=on|iommu=pt' /proc/cmdline | tr '\n' ' ')"
  else
    row info "IOMMU on the kernel command line" "not set" "AMD turns it on by default; Intel may need intel_iommu=on"
  fi
  local groups
  groups=$(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l)
  if [ "$groups" -gt 0 ]; then row ok "IOMMU groups" "$groups"
  else row info "IOMMU groups" "none" "The IOMMU is off, so passthrough won't work"; fi
  if modinfo vfio-pci >/dev/null 2>&1 || [ -d /sys/bus/pci/drivers/vfio-pci ]; then row ok "vfio-pci" "available"
  else row info "vfio-pci" "not available"; fi
  local gvt
  gvt=$(ls -d /sys/bus/pci/devices/*/mdev_supported_types/i915-* 2>/dev/null | head -1)
  if [ -n "$gvt" ]; then row ok "GVT-g" "${gvt##*/}" "and $(ls -d /sys/bus/pci/devices/*/mdev_supported_types/i915-* | wc -l) types in all"
  else row info "GVT-g" "not available" "Needs an Intel GPU up to 10th generation and i915.enable_gvt=1"; fi
}

# --- macOS host ----------------------------------------------------------------------

check_macos_host() {
  section "System"
  row info "macOS" "$(sw_vers -productVersion)"
  local chip
  chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
  if [ "$(uname -m)" = arm64 ]; then row ok "CPU" "$chip"
  else row warn "CPU" "$chip" "krunkit needs Apple silicon; QEMU on an Intel Mac has no GPU acceleration for Linux guests"; fi

  section "krunkit (Vulkan through Venus and MoltenVK)"
  if have krunkit; then row ok "krunkit" "$(krunkit --version 2>/dev/null | awk '{print $NF}')"
  else row info "krunkit" "not installed" "brew install krunkit"; fi
  if have brew; then
    local v
    for pkg in libkrun molten-vk; do
      v=$(brew list --versions "$pkg" 2>/dev/null | awk '{print $NF}')
      if [ -n "$v" ]; then row ok "$pkg" "$v"
      else row info "$pkg" "not installed" "krunkit installs it"; fi
    done
  fi

  section "QEMU"
  if have qemu-system-aarch64; then
    row info "QEMU" "$(qemu-system-aarch64 --version | sed -n '1s/.*version //p')"
    if qemu-system-aarch64 -device help 2>/dev/null | grep -q '"virtio-gpu-gl-pci"'; then
      row ok "QEMU virtio-gpu-gl-pci" "available"
    else
      row info "QEMU virtio-gpu-gl-pci" "missing" "Homebrew's QEMU has no OpenGL; the guest gets a 2D virtio-gpu only"
    fi
  else
    row info "QEMU" "not installed"
  fi
}

# --- Main ----------------------------------------------------------------------------

case $(uname -s) in
  Darwin) check_macos_host ;;
  Linux)
    if [ -z "$mode" ]; then
      virt=$(systemd-detect-virt --vm 2>/dev/null || true)
      if [ -n "$virt" ] && [ "$virt" != none ]; then mode=guest
      elif grep -qw hypervisor /proc/cpuinfo 2>/dev/null; then mode=guest
      else mode=host; fi
    fi
    if [ "$mode" = guest ]; then check_guest; else check_linux_host; fi ;;
  *) echo "Unsupported system: $(uname -s)" >&2; exit 2 ;;
esac

section "Summary"
plural() { [ "$1" = 1 ] && echo "$1 $2" || echo "$1 ${2}s"; }
if [ $failed -gt 0 ]; then
  printf '%s%d missing, %s%s\n' "$c_bad" "$failed" "$(plural "$warned" warning)" "$c_off"
  exit 1
elif [ $warned -gt 0 ]; then
  printf '%s%s%s\n' "$c_warn" "$(plural "$warned" warning)" "$c_off"
else
  printf '%sEverything checked is in place%s\n' "$c_ok" "$c_off"
fi
