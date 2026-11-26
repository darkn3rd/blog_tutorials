# Builds a Vagrant box for VirtualBox from Ubuntu's cloud image.
#
#   source  imports the cloud image's disk, which the Makefile wrapped in an
#           OVF, and boots it with a cloud-init seed that creates the vagrant user
#   build   runs the cleanup script in the VM, then the vagrant post-processor
#           packages the exported VM as a box
#
# The Makefile passes the variables; run `make box` rather than `packer build`.

packer {
  required_version = ">= 1.10.0"
  required_plugins {
    virtualbox = {
      source  = "github.com/hashicorp/virtualbox"
      version = "~> 1"
    }
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = "~> 1"
    }
  }
}

variable "ovf" {
  type        = string
  description = "Path to the OVF that wraps the cloud image's disk"
}

variable "box_file" {
  type        = string
  description = "Where to write the box"
}

variable "ssh_private_key_file" {
  type        = string
  description = "Vagrant's insecure private key, which matches the key in cloud-init/user-data"
}

source "virtualbox-ovf" "ubuntu" {
  # Packer can't import a qcow2 disk, so it starts from an OVF instead.
  source_path      = var.ovf
  checksum         = "none"
  output_directory = "${path.root}/.build/packer"
  vm_name          = "ubuntu-26.04"
  headless         = true

  # The cloud image has no Guest Additions, and this box doesn't add them.
  # Packer also skips writing the VirtualBox version to ~/.vbox_version.
  guest_additions_mode    = "disable"
  virtualbox_version_file = ""

  # Packer builds the cloud-init seed, an ISO labelled "cidata" holding these
  # files, and attaches it as a DVD. Arm VMs have no IDE controller, so
  # guest_additions_interface tells Packer to use the controller named "SATA"
  # in the OVF instead; the setting covers all the ISOs Packer attaches.
  cd_files                  = ["${path.root}/cloud-init/user-data", "${path.root}/cloud-init/meta-data"]
  cd_label                  = "cidata"
  guest_additions_interface = "sata"

  # Log in as the user cloud-init creates.
  communicator         = "ssh"
  ssh_username         = "vagrant"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "10m"
  shutdown_command     = "sudo shutdown -P now"
}

build {
  sources = ["source.virtualbox-ovf.ubuntu"]

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/cleanup.sh"
  }

  # Packages the exported VM as a VirtualBox box and deletes the export afterwards.
  post-processor "vagrant" {
    output = var.box_file
  }
}
