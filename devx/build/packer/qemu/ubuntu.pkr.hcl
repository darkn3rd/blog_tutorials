# Builds a Vagrant box for the vagrant-qemu provider from Ubuntu's cloud image.
#
#   source  boots the cloud image in QEMU, with a cloud-init seed that creates
#           the vagrant user
#   build   runs the cleanup script in the VM, then the vagrant post-processor
#           packages the disk as a box
#
# The Makefile passes the variables; run `make box` rather than `packer build`.

packer {
  required_version = ">= 1.10.0"
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = "~> 1"
    }
  }
}

variable "image" {
  type        = string
  description = "Path to the downloaded cloud image"
}

variable "image_checksums" {
  type        = string
  description = "URL of Ubuntu's SHA256SUMS file, which Packer checks the image against"
}

variable "box_file" {
  type        = string
  description = "Where to write the box"
}

variable "ssh_private_key_file" {
  type        = string
  description = "Vagrant's insecure private key, which matches the key in cloud-init/user-data"
}

variable "qemu_share" {
  type        = string
  description = "QEMU's share directory, which holds the UEFI firmware"
}

source "qemu" "ubuntu" {
  # The cloud image is already a bootable disk, so Packer copies it instead of
  # installing from an ISO, then grows the copy to disk_size.
  iso_url      = var.image
  iso_checksum = "file:${var.image_checksums}"
  disk_image   = true
  disk_size    = "20G"
  format       = "qcow2"

  output_directory = "${path.root}/.build"
  vm_name          = "ubuntu-26.04.qcow2"

  # An Arm VM on Apple's Hypervisor framework, booting with UEFI.
  qemu_binary       = "qemu-system-aarch64"
  machine_type      = "virt"
  accelerator       = "hvf"
  cpu_model         = "host"
  cpus              = 2
  memory            = 2048
  efi_boot          = true
  efi_firmware_code = "${var.qemu_share}/edk2-aarch64-code.fd"
  efi_firmware_vars = "${var.qemu_share}/edk2-arm-vars.fd"
  efi_drop_efivars  = true

  net_device         = "virtio-net-pci"
  disk_interface     = "virtio"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  headless           = true
  display            = "none"

  # Packer builds the cloud-init seed: an ISO labelled "cidata" holding these files.
  cd_files        = ["${path.root}/cloud-init/user-data", "${path.root}/cloud-init/meta-data"]
  cd_label        = "cidata"
  cdrom_interface = "virtio-scsi"

  # Log in as the user cloud-init creates.
  communicator         = "ssh"
  ssh_username         = "vagrant"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "10m"
  shutdown_command     = "sudo shutdown -P now"
}

build {
  sources = ["source.qemu.ubuntu"]

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/cleanup.sh"
  }

  # Packages the qcow2 disk as a box in vagrant-libvirt's format, which
  # vagrant-qemu reads, and deletes the disk afterwards.
  post-processor "vagrant" {
    output = var.box_file
  }
}
