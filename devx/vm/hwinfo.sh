#!/usr/bin/env bash
# Report the virtual hardware a Linux guest sees: platform, firmware and boot path, CPU,
# video/GPU, OS and the main devices. hwinfo-all.sh runs it in every tutorial's VM; to
# run it by hand, copy it into a guest and run:
#
#   ./hwinfo.sh                              # print a Markdown report
#   ./hwinfo.sh --label lima/ansible         # also append it to hardware.tsv
#
# hardware.tsv sits next to this script (change it with --file). It holds one row per
# value, so runs from different VM tools can be lined up:
#
#   ./hwinfo.sh --compare                    # one column per label, newest run of each
#   ./hwinfo.sh --tsv                        # raw section/field/value rows, for scripts
#
# --compare only needs awk, so it also works on the macOS host. Some values (dmesg lines
# about the GPU) need root; run with sudo for the fullest report. Nothing is installed or
# changed, and missing tools only leave their rows as n/a.
set -uo pipefail
export LC_ALL=C

script_dir=$(cd "$(dirname "$0")" && pwd)
file=$script_dir/hardware.tsv
label=""
mode=report

usage() { sed -n '2,17s/^# \{0,1\}//p' "$0"; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case $1 in
    --label)   label=${2:?--label needs a name}; shift ;;
    --file)    file=${2:?--file needs a path}; shift ;;
    --compare) mode=compare ;;
    --tsv)     mode=tsv ;;
    -h|--help) usage ;;
    *)         echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
  shift
done

md() { local v=${1//|/\\|}; printf '%s' "$v"; }

# ---------------------------------------------------------------------------------------
# --compare: pivot hardware.tsv into one Markdown table per section.
if [ "$mode" = compare ]; then
  [ -s "$file" ] || { echo "No data in $file. Run with --label first." >&2; exit 1; }
  awk -F'\t' '
    FNR == 1 { next }                                  # header
    NR == FNR { latest[$2] = $1; next }                # pass 1: newest run per label
    $1 != latest[$2] { next }
    {
      if (!($2 in seen_label)) { seen_label[$2] = 1; labels[++nl] = $2 }
      if (!($3 in seen_sec))   { seen_sec[$3] = 1;   secs[++ns] = $3 }
      key = $3 SUBSEP $4
      if (!(key in seen_key))  { seen_key[key] = 1;  fields[$3, ++nf[$3]] = $4 }
      val[$2, key] = $5
    }
    function esc(s) { gsub(/\|/, "\\|", s); return s }
    END {
      for (s = 1; s <= ns; s++) {
        sec = secs[s]
        printf "### %s\n\n| Field |", sec
        for (l = 1; l <= nl; l++) printf " %s |", esc(labels[l])
        printf "\n| --- |"
        for (l = 1; l <= nl; l++) printf " --- |"
        printf "\n"
        for (f = 1; f <= nf[sec]; f++) {
          fld = fields[sec, f]
          printf "| %s |", esc(fld)
          for (l = 1; l <= nl; l++) {
            k = labels[l] SUBSEP sec SUBSEP fld
            printf " %s |", (k in val) ? esc(val[k]) : ""
          }
          printf "\n"
        }
        printf "\n"
      }
      printf "Newest run per label:"
      for (l = 1; l <= nl; l++) printf " %s (%s)%s", labels[l], latest[labels[l]], (l < nl ? "," : "")
      printf "\n"
    }' "$file" "$file"
  exit
fi

[ "$(uname -s)" = Linux ] || { echo "Run this inside a Linux guest (or use --compare)." >&2; exit 1; }

# ---------------------------------------------------------------------------------------
# Helpers
rows=()
section=""
sec() { section=$1; }
add() {
  local v=${2:-}
  v=$(printf '%s' "$v" | tr '\t\n' '  ' | sed 's/  */ /g; s/^ //; s/ $//')
  [ -n "$v" ] || v="n/a"
  rows+=("$section"$'\t'"$1"$'\t'"$v")
}
have() { command -v "$1" >/dev/null 2>&1; }
rd()   { [ -r "$1" ] && tr -d '\0' <"$1" 2>/dev/null | sed 's/[[:space:]]*$//'; }
dmi()  { rd "/sys/class/dmi/id/$1"; }
lscpu_get() { have lscpu && lscpu 2>/dev/null | sed -n "s/^$1:[[:space:]]*//p" | head -1; }
cpuinfo_get() { sed -n "s/^$1[[:space:]]*:[[:space:]]*//p" /proc/cpuinfo | head -1; }
join_lines() { paste -sd, - | sed 's/,/, /g'; }
# Like join_lines, but collapses repeats into "2x item"
count_lines() { sort | uniq -c | awk '{ c = $1; $1 = ""; sub(/^ /, ""); print (c > 1 ? c "x " : "") $0 }' | join_lines; }
# Kernel log: dmesg needs root on Ubuntu, journalctl works for the adm group.
klog() { { dmesg 2>/dev/null || journalctl -k -b --no-pager -q 2>/dev/null; } | sed 's/^\[[^]]*\] //'; }
efivar() { ls /sys/firmware/efi/efivars/"$1"-* 2>/dev/null | head -1; }

arch=$(uname -m)

# ---------------------------------------------------------------------------------------
sec "Platform"
virt=$(systemd-detect-virt --vm 2>/dev/null) || true
add "Hypervisor (systemd-detect-virt)" "$virt"
hv_vendor=$(lscpu_get "Hypervisor vendor")
[ -n "$hv_vendor" ] && add "Hypervisor vendor (CPUID)" "$hv_vendor"
add "System vendor" "$(dmi sys_vendor)"
add "System product" "$(dmi product_name)"
add "System version" "$(dmi product_version)"
add "Board" "$(printf '%s %s' "$(dmi board_vendor)" "$(dmi board_name)")"
if [ -d /proc/device-tree ]; then
  add "Device tree model" "$(rd /proc/device-tree/model)"
  add "Device tree compatible" \
    "$(tr '\0' '\n' </proc/device-tree/compatible 2>/dev/null | join_lines)"
fi
desc=""
[ -d /sys/firmware/acpi/tables ] && desc="ACPI"
[ -d /sys/firmware/devicetree/base ] && desc="${desc:+$desc + }device tree"
add "Hardware description" "$desc"
[ -d /sys/firmware/acpi/tables ] &&
  add "ACPI tables" "$(ls /sys/firmware/acpi/tables | grep -E '^[A-Z0-9]{4}[0-9]*$' |
                       sed 's/[0-9]*$//' | sort -u | join_lines)"

# ---------------------------------------------------------------------------------------
sec "Firmware and boot"
bios_vendor=$(dmi bios_vendor)
if [ -d /sys/firmware/efi ]; then
  bits=$(rd /sys/firmware/efi/fw_platform_size)
  boot="UEFI${bits:+ (${bits}-bit)}"
elif [ -n "$bios_vendor" ] && [[ $arch == x86_64 || $arch == i?86 ]]; then
  boot="Legacy BIOS"
elif [ -d /sys/firmware/devicetree/base ]; then
  boot="No EFI: direct kernel boot with a device tree"
else
  boot="No EFI and no firmware tables: likely direct kernel boot"
fi
add "Boot mode" "$boot"
add "Firmware vendor" "$bios_vendor"
add "Firmware version" "$(printf '%s %s' "$(dmi bios_version)" "$(dmi bios_date)")"
if [ -d /sys/firmware/efi ]; then
  sb=$(efivar SecureBoot)
  if [ -n "$sb" ]; then
    case $(od -An -t u1 -j4 -N1 "$sb" 2>/dev/null | tr -d ' ') in
      1) add "Secure Boot" "enabled" ;;
      0) add "Secure Boot" "disabled" ;;
      *) add "Secure Boot" "unknown" ;;
    esac
  else
    add "Secure Boot" "not offered by firmware"
  fi
  nvars=$(ls /sys/firmware/efi/efivars 2>/dev/null | wc -l | tr -d ' ')
  add "EFI variables" "$([ "$nvars" -gt 0 ] && echo "$nvars visible" || echo "none (no runtime NVRAM)")"
  entry=""
  if have efibootmgr; then
    cur=$(efibootmgr 2>/dev/null | sed -n 's/^BootCurrent: //p')
    [ -n "$cur" ] && entry=$(efibootmgr 2>/dev/null | sed -n "s/^Boot$cur\*\{0,1\} //p" |
                             sed 's/\t.*//; s/[[:space:]]*\(HD\|PciRoot\|VenHw\|FvVol\|MAC\)(.*//')
  fi
  add "EFI boot entry" "${entry:+$entry (Boot$cur)}"
fi
loader=""
li=$(efivar LoaderInfo)
if [ -n "$li" ]; then
  loader=$(tail -c +5 "$li" | tr -d '\0')
elif grep -q 'BOOT_IMAGE=' /proc/cmdline; then
  loader="GRUB (BOOT_IMAGE= on the kernel command line)"
elif [ -d /sys/firmware/efi ]; then
  loader="none detected (EFI stub or UKI?)"
else
  loader="none detected (kernel loaded by the VMM?)"
fi
add "Bootloader" "$loader"
add "Kernel command line" "$(cat /proc/cmdline)"
add "Init (PID 1)" "$(ps -p 1 -o comm= 2>/dev/null)"
have systemd-analyze &&
  add "Boot time (systemd-analyze)" \
    "$(systemd-analyze time 2>/dev/null | head -1 | sed 's/^Startup finished in //')"

# ---------------------------------------------------------------------------------------
sec "CPU"
add "Architecture" "$arch"
vendor=$(lscpu_get "Vendor ID")
model=$(lscpu_get "Model name")
if [ -z "$model" ] || [ "$model" = "-" ]; then
  model=$(cpuinfo_get "model name")
  part=$(cpuinfo_get "CPU part")
  [ -z "$model" ] && [ -n "$part" ] && model="CPU part $part"
fi
add "Vendor" "${vendor:-$(cpuinfo_get "CPU implementer")}"
add "Model" "$model"
add "vCPUs" "$(nproc)"
s=$(lscpu_get "Socket(s)"); c=$(lscpu_get "Core(s) per socket"); [ -z "$c" ] && c=$(lscpu_get "Core(s) per cluster")
t=$(lscpu_get "Thread(s) per core")
add "Topology (sockets x cores x threads)" "$([ -n "$c$t" ] && echo "${s:--} x ${c:--} x ${t:--}")"
flags=$(cpuinfo_get "flags"); [ -z "$flags" ] && flags=$(cpuinfo_get "Features")
case $arch in
  x86_64|i?86) wanted="hypervisor vmx svm sse4_2 avx avx2 avx512f aes sha_ni rdrand x2apic constant_tsc" ;;
  *)           wanted="aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd sve sve2 bf16 i8mm paca" ;;
esac
present=""
for f in $wanted; do
  [[ " $flags " == *" $f "* ]] && present="$present $f"
done
add "Notable flags" "${present# }"
add "Nested virtualization (/dev/kvm)" "$([ -e /dev/kvm ] && echo yes || echo no)"
add "Clocksource" "$(rd /sys/devices/system/clocksource/clocksource0/current_clocksource)"
add "Memory" "$(awk '/^MemTotal:/ { printf "%.1f GiB", $2 / 1048576 }' /proc/meminfo)"

# ---------------------------------------------------------------------------------------
sec "Video and GPU"
pci_name() { have lspci && lspci -nn -s "$1" 2>/dev/null | sed 's/^[^ ]* //' | head -1; }
cards=0
for card in /sys/class/drm/card*; do
  name=${card##*/}
  [[ $name =~ ^card[0-9]+$ ]] || continue
  cards=$((cards + 1))
  drv=$(basename "$(readlink -f "$card/device/driver")" 2>/dev/null)
  devpath=$(readlink -f "$card/device")
  where=""
  if [[ $devpath == */pci* ]]; then
    slot=${devpath##*/}
    # virtio-gpu sits on a virtioN node whose parent is the PCI function
    [[ $slot == virtio* ]] && slot=$(basename "$(dirname "$devpath")")
    pn=$(pci_name "$slot")
    where="PCI $slot${pn:+: $pn}"
  else
    where="$(basename "$(dirname "$devpath")")/${devpath##*/}"
  fi
  # A virtio GPU's card hangs off its transport (virtio-pci or virtio-mmio); the GPU
  # driver, virtio_gpu, is on the transport's virtioN child.
  for v in "$devpath"/virtio*/driver; do
    [ -e "$v" ] && { where="${drv:+$drv, }$where"; drv=$(basename "$(readlink -f "$v")"); }
  done
  add "DRM $name" "${drv:-no driver} ($where)"
done
[ $cards -eq 0 ] && add "DRM devices" "none"
if have lspci; then
  disp=$(lspci -nn 2>/dev/null | grep -E '\[03[0-9]{2}\]' | sed 's/^[^ ]* //; s/ (rev [0-9a-f]*)$//' | count_lines)
  add "PCI display controllers" "${disp:-none}"
else
  disp=""
  for d in /sys/bus/pci/devices/*; do
    [[ $(rd "$d/class") == 0x03* ]] && disp="$disp ${d##*/} [$(rd "$d/vendor" | cut -c3-):$(rd "$d/device" | cut -c3-)]"
  done
  disp=${disp# }
  add "PCI display controllers" "${disp:-none}"
fi
conns=""
for c in /sys/class/drm/card*-*; do
  [ -e "$c/status" ] || continue
  st=$(rd "$c/status")
  res=$(head -1 "$c/modes" 2>/dev/null)
  conns="$conns, ${c##*/card[0-9]-} $st${res:+ $res}"
done
conns=${conns#, }
add "Connectors" "${conns:-none}"
v=$(ls /dev/dri/renderD* 2>/dev/null | join_lines); add "Render nodes" "${v:-none}"
v=$(for f in /sys/class/graphics/fb*; do rd "$f/name"; done 2>/dev/null | join_lines)
add "Framebuffer" "${v:-none}"
gpu_log=$(klog | grep -iE 'virtio[-_]gpu|\[drm\] features|virgl|venus' | grep -iE 'features|virgl|venus|blob' | head -3 | join_lines)
add "virtio-gpu features (kernel log)" "${gpu_log:-$([ "$(id -u)" -eq 0 ] && echo none || echo 'n/a (try sudo)')}"
if have vulkaninfo; then
  add "Vulkan devices" "$(vulkaninfo --summary 2>/dev/null | sed -n 's/^[[:space:]]*deviceName[[:space:]]*= //p' | join_lines)"
fi
if have glxinfo && [ -n "${DISPLAY:-}" ]; then
  add "OpenGL renderer" "$(glxinfo -B 2>/dev/null | sed -n 's/^OpenGL renderer string: //p')"
fi

# ---------------------------------------------------------------------------------------
sec "OS"
pretty="" ; os_id="" ; ver="" ; codename=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  pretty=$(. /etc/os-release; echo "${PRETTY_NAME:-}")
  os_id=$(. /etc/os-release; echo "${ID:-}")
  ver=$(. /etc/os-release; echo "${VERSION_ID:-}")
  codename=$(. /etc/os-release; echo "${VERSION_CODENAME:-}")
fi
add "Distribution" "$pretty"
add "ID / version / codename" "$os_id ${ver:--} ${codename:--}"
add "Kernel" "$(uname -r)"
add "Kernel build" "$(uname -v)"
add "Hostname" "$(hostname)"
ds=""
have cloud-id && ds=$(cloud-id 2>/dev/null)
[ -z "$ds" ] && [ -r /run/cloud-init/instance-data.json ] &&
  ds=$(sed -n 's/.*"platform": "\([^"]*\)".*/\1/p' /run/cloud-init/instance-data.json | head -1)
add "cloud-init datasource" "${ds:-$([ -d /run/cloud-init ] && echo unknown || echo 'not used')}"

# ---------------------------------------------------------------------------------------
sec "Devices"
virtio_name() {
  case $(( $1 )) in
    1) echo net ;; 2) echo block ;; 3) echo console ;; 4) echo rng ;; 5) echo balloon ;;
    8) echo scsi ;; 9) echo 9p ;; 16) echo gpu ;; 18) echo input ;; 19) echo vsock ;;
    20) echo crypto ;; 26) echo fs ;; 27) echo pmem ;; 29) echo mem ;; 35) echo sound ;;
    *) echo "id $1" ;;
  esac
}
vlist=""
for d in /sys/bus/virtio/devices/virtio*; do
  [ -e "$d/device" ] || continue
  n=$(virtio_name "$(rd "$d/device")")
  drv=$(basename "$(readlink -f "$d/driver")" 2>/dev/null)
  p=$(readlink -f "$d")
  if [[ $p == */pci* ]]; then tr=PCI; elif [[ $p == *mmio* ]]; then tr=MMIO; else tr=other; fi
  vlist="$vlist$n ($tr${drv:+, $drv})"$'\n'
done
if [ -n "$vlist" ]; then
  add "virtio devices" "$(printf '%s' "$vlist" | count_lines)"
else
  add "virtio devices" "none"
fi
nics=""
for n in /sys/class/net/*; do
  [ "${n##*/}" = lo ] && continue
  [ -e "$n/device" ] || continue          # skip bridges, veths and other virtual links
  nics="$nics, ${n##*/}: $(basename "$(readlink -f "$n/device/driver")")"
done
add "Network interfaces" "${nics#, }"
if have lsblk; then
  add "Disks" "$(lsblk -dn -o NAME,SIZE,TRAN,MODEL 2>/dev/null | grep -vE '^(loop|ram|zram)' |
                 awk '{ $1 = $1; print }' | join_lines)"
fi
have lspci &&
  add "Storage controllers" "$(lspci -nn 2>/dev/null | grep -E '\[01[0-9]{2}\]' | sed 's/^[^ ]* //; s/ (rev [0-9a-f]*)$//' | count_lines)"
add "File shares" "$(awk '$3 ~ /^(9p|virtiofs|vboxsf|fuse\.sshfs|nfs4?|cifs)$/ { print $2 " (" $3 ", " $1 ")" }' /proc/mounts | join_lines)"

# ---------------------------------------------------------------------------------------
# Output
if [ "$mode" = tsv ]; then
  printf '%s\n' "${rows[@]}"
  exit
fi
run_at=$(date '+%Y-%m-%d %H:%M')
title=${label:-$(hostname)}
echo "## $title ($run_at)"
last=""
for r in "${rows[@]}"; do
  IFS=$'\t' read -r s f v <<<"$r"
  if [ "$s" != "$last" ]; then
    printf '\n### %s\n\n| Field | Value |\n| --- | --- |\n' "$s"
    last=$s
  fi
  printf '| %s | %s |\n' "$(md "$f")" "$(md "$v")"
done

if [ -n "$label" ]; then
  if { [ -f "$file" ] || printf 'run_at\tlabel\tsection\tfield\tvalue\n' >"$file"; } 2>/dev/null &&
     printf '%s\n' "${rows[@]}" | sed "s|^|$run_at\t$label\t|" >>"$file" 2>/dev/null; then
    echo
    echo "Appended ${#rows[@]} rows to $file"
  else
    echo "Could not write $file (read-only share?). Use --file to pick another path." >&2
    exit 1
  fi
fi
