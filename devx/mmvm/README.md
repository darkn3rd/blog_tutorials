# Multi-machine VMs

Tutorials that create several virtual machines that work together, such as a web app on
one VM and Redis on another, and configure them as a group. Folders are named by VM tool
first, then by configuration tool. Every tutorial stands on its own, with its own README.

## Folders

| Folder | VM tool | Runs the VMs with | Configuration | VMs |
| --- | --- | --- | --- | --- |
| [`lima/ansible`](lima/ansible) | Lima | Apple's Virtualization framework | Ansible | An HAProxy load balancer in front of three nginx app servers |
| [`vagrant/virtualbox/ansible`](vagrant/virtualbox/ansible) | Vagrant | VirtualBox, Vagrant's default provider | Ansible | An HAProxy load balancer in front of three nginx app servers |
