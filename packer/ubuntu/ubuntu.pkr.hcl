source "virtualbox-iso" "ubuntu" {
  vm_name              = "ubuntu-${var.ubuntu_version}-${var.arch}"
  iso_url              = local.target.iso_url
  iso_checksum         = local.target.iso_checksum
  iso_interface        = local.target.iso_interface
  guest_os_type        = local.target.guest_os_type
  hard_drive_interface = local.target.hard_drive_interface
  nic_type             = local.target.nic_type
  vboxmanage           = local.target.vboxmanage

  cpus      = 2
  memory    = 4096
  disk_size = 40960
  firmware  = "efi"
  headless  = var.headless

  # No Guest Additions ISO to attach; the build doesn't need it
  guest_additions_mode = "disable"

  # Lets fstrim in scripts/cleanup.sh release free blocks from the disk image
  hard_drive_discard       = true
  hard_drive_nonrotational = true

  communicator = "ssh"
  ssh_port     = 22
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout  = "30m"

  # Drop to the GRUB command line and boot the installer with the autoinstall data served below
  boot_wait = "10s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall 'ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
  http_directory = "${path.root}/http"
  http_port_min  = 8000
  http_port_max  = 8000

  shutdown_command = "sudo shutdown -h now"
  output_directory = "${var.build_dir}/output-ubuntu-${var.arch}"
}

build {
  sources = ["source.virtualbox-iso.ubuntu"]

  provisioner "shell" {
    script          = "${path.root}/scripts/provision.sh"
    execute_command = "sudo bash '{{ .Path }}'"
  }

  # Last step: drop caches and free space so the exported disk compresses well
  provisioner "shell" {
    script          = "${path.root}/scripts/cleanup.sh"
    execute_command = "sudo bash '{{ .Path }}'"
  }

  post-processors {
    post-processor "vagrant" {
      keep_input_artifact = false
      provider_override   = "virtualbox"
      compression_level   = 9
      output              = "${var.build_dir}/ubuntu-${var.ubuntu_version}-virtualbox-${var.arch}.box"
    }
  }
}
