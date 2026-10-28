locals {
  ubuntu_mirror = "https://releases.ubuntu.com/${var.ubuntu_version}"
  # Ubuntu publishes arm64 images on a different host than amd64
  arm64_mirror = "https://cdimage.ubuntu.com/releases/${var.ubuntu_version}/release"

  # Everything that differs between the two architectures. VirtualBox can't emulate
  # the other one, so each box has to be built on a host of its own architecture.
  arches = {
    amd64 = {
      iso_url              = "${local.ubuntu_mirror}/ubuntu-${var.ubuntu_version}-live-server-amd64.iso"
      iso_checksum         = "file:${local.ubuntu_mirror}/SHA256SUMS"
      guest_os_type        = "Ubuntu_64"
      iso_interface        = "sata"
      hard_drive_interface = "sata"
      nic_type             = "82540EM"
      vboxmanage           = []
    }
    arm64 = {
      iso_url              = "${local.arm64_mirror}/ubuntu-${var.ubuntu_version}-live-server-arm64.iso"
      iso_checksum         = "file:${local.arm64_mirror}/SHA256SUMS"
      guest_os_type        = "Ubuntu_arm64"
      iso_interface        = "virtio"
      hard_drive_interface = "virtio"
      nic_type             = "virtio"
      # The arm64 VM has no PS/2 or legacy devices, so it needs USB input and a VMSVGA display
      vboxmanage = [
        ["modifyvm", "{{.Name}}", "--graphicscontroller", "vboxsvga"],
        ["modifyvm", "{{.Name}}", "--vram", "64"],
        ["modifyvm", "{{.Name}}", "--usb-xhci", "on"],
        ["modifyvm", "{{.Name}}", "--keyboard", "usb"],
        ["modifyvm", "{{.Name}}", "--mouse", "usbtablet"]
      ]
    }
  }

  target = local.arches[var.arch]
}
