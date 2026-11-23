#!/bin/sh
# Run as root by `make machine`, from the project folder, right after the import.
set -eu

user=gentoo

id "$user" >/dev/null 2>&1 ||
  useradd --create-home --uid 1000 --groups wheel --shell /bin/bash "$user"

# sudo itself is installed by guest/install-ansible.sh.
mkdir -p /etc/sudoers.d
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$user" > "/etc/sudoers.d/$user"
chmod 0440 "/etc/sudoers.d/$user"

ln -sfn "$PWD" /workspace

# wsl.exe sets LANG from the Windows display language, but the stage3 only has C.UTF-8,
# and Ansible won't start without a working locale.
case "${LANG:-}" in
  *.UTF-8)
    grep -qx "$LANG UTF-8" /etc/locale.gen || echo "$LANG UTF-8" >> /etc/locale.gen
    # locale-gen is a Perl script, and Perl warns about a LANG that isn't built yet.
    LC_ALL=C.UTF-8 locale-gen
    ;;
esac
