# Building VM images on macOS

Each project here builds a virtual machine image from Ubuntu's official 26.04 cloud
image, locally on a Mac. Folders are named by the tool that builds the image, then by
the provider or backend the image is for, such as `packer/qemu`. Every project stands on its own, with
its own README.

## Folders

| Folder | Builds | Built with |
| --- | --- | --- |
| [`vagrant/qemu`](vagrant/qemu) | A Vagrant box for the vagrant-qemu provider | Vagrant, vagrant-qemu, QEMU and cloud-init |
| [`vagrant/virtualbox`](vagrant/virtualbox) | A Vagrant box for VirtualBox | Vagrant, VirtualBox and cloud-init |
| [`packer/qemu`](packer/qemu) | A Vagrant box for the vagrant-qemu provider | Packer's QEMU builder and cloud-init |
| [`packer/virtualbox`](packer/virtualbox) | A Vagrant box for VirtualBox | Packer's VirtualBox builder and cloud-init |
