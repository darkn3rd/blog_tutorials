# Building VM images on macOS

Each project here builds a virtual machine image from Ubuntu's official 26.04 cloud
image, locally on a Mac. Folders are named by the tool that uses the image first, then
by its provider or backend, such as `vagrant/qemu`. Every project stands on its own, with
its own README.

## Folders

| Folder | Builds | Built with |
| --- | --- | --- |
| [`vagrant/qemu`](vagrant/qemu) | A Vagrant box for the vagrant-qemu provider | Vagrant, vagrant-qemu, QEMU and cloud-init |
| [`vagrant/virtualbox`](vagrant/virtualbox) | A Vagrant box for VirtualBox | Vagrant, VirtualBox and cloud-init |
