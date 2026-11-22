# Virtual machines on macOS and Linux

Each tutorial here creates an Ubuntu virtual machine on a Mac or a Linux host,
depending on the tutorial (see [Hosts](#hosts)), with one VM tool, then configures it
with one configuration tool.
Folders are named by VM tool first, then by configuration tool, such as
`vagrant/virtualbox/ansible`. Every tutorial stands on its own, with its own README.

The configuration installs a small web server and copies in a page, so there is something
to check once the VM is configured. Today every tutorial uses Ansible; other configuration
tools, such as Puppet, Chef or Salt, go in folders next to `ansible`.

## Folders

| Folder | VM tool | Runs the VM with | Configuration |
| --- | --- | --- | --- |
| [`lima/ansible`](lima/ansible) | Lima | Apple's Virtualization framework on macOS, QEMU with KVM on Linux | Ansible |
| [`qemu/ansible`](qemu/ansible) | QEMU, from a Makefile | Apple's Hypervisor framework on macOS, KVM on Linux | Ansible |
| [`krunkit/ansible`](krunkit/ansible) | krunkit (libkrun), from a Makefile, with gvproxy for the network | Apple's Hypervisor framework | Ansible |
| [`vfkit/ansible`](vfkit/ansible) | vfkit, from a Makefile, with gvproxy for the network | Apple's Virtualization framework | Ansible |
| [`virtualbox/ansible`](virtualbox/ansible) | VirtualBox, with `VBoxManage` from a Makefile | VirtualBox | Ansible |
| [`libvirt/ansible`](libvirt/ansible) | libvirt, with `virsh` from a Makefile, **on Linux** | QEMU with KVM | Ansible |
| [`vagrant/virtualbox/ansible`](vagrant/virtualbox/ansible) | Vagrant | VirtualBox, Vagrant's default provider | Ansible |
| [`vagrant/qemu/ansible`](vagrant/qemu/ansible) | Vagrant with the vagrant-qemu plugin | QEMU | Ansible |
| [`vagrant/avf/ansible`](vagrant/avf/ansible) | Vagrant with the vagrant-provider-avf plugin | Apple's Virtualization framework | Ansible |
| [`vagrant/libvirt/ansible`](vagrant/libvirt/ansible) | Vagrant with the vagrant-libvirt plugin, **on Linux** | libvirt, running QEMU with KVM | Ansible |

Apple provides two frameworks for running VMs:

- **Hypervisor framework** is the low-level one. It gives a program the Mac's CPU
  virtualization: virtual CPUs and guest memory. The program has to provide everything
  else itself, such as the disks, network and display. QEMU emulates those devices and
  uses the Hypervisor framework when it's started with `-accel hvf`. libkrun, which
  krunkit runs, is a smaller monitor on the same framework that provides only virtio
  devices.
- **Virtualization framework** is built on top of the Hypervisor framework and provides
  complete VMs: boot loaders, virtio disks and networking, and shared folders. Programs
  that use it, like Lima and vfkit, configure a VM rather than emulate its hardware.

The `qemu`, `krunkit`, `vfkit` and `virtualbox` tutorials run the VM without a VM
manager, so their Makefiles do the work one would otherwise do: download the image, create
the disk, set up the user with cloud-init, boot and shut down. `vagrant/qemu` and `vagrant/virtualbox` run the
same hypervisors through Vagrant, for comparison.

Two tutorials run only on Linux, where libvirt runs QEMU with KVM.
`libvirt/ansible` has libvirt start QEMU, so its Makefile writes a domain XML file and
runs `virsh` instead of building QEMU flags. `vagrant/libvirt/ansible` uses the same
libvirt build of the box as `vagrant/qemu/ansible`.

## Hosts

| Folder | macOS | Linux | Windows |
| --- | --- | --- | --- |
| `lima/ansible` | Yes | x86_64, tested | No |
| `qemu/ansible` | Apple Silicon | x86_64, tested | No |
| `krunkit/ansible` | Apple Silicon | No | No |
| `vfkit/ansible` | Yes | No | No |
| `virtualbox/ansible` | Apple Silicon | x86_64; not tested yet | No |
| `libvirt/ansible` | No | Tested | No |
| `vagrant/virtualbox/ansible` | Yes | Should work; not tested yet | Windows 11, tested |
| `vagrant/qemu/ansible` | Yes | Not set up | No |
| `vagrant/avf/ansible` | Yes, partly; see its README | No | No |
| `vagrant/libvirt/ansible` | No | Tested | No |

`qemu/ansible` and `virtualbox/ansible` keep what differs per host in
`platform/<OS>-<arch>.mk` files, which the Makefile includes. `krunkit`, `vfkit` and
`vagrant/avf` use Apple's frameworks, so they can't run on Linux. On Linux, VirtualBox
and KVM can conflict; the VirtualBox READMEs explain how to tell and what to do.

## How they work

| Folder | How Ansible runs | Web page |
| --- | --- | --- |
| `lima/ansible` | `ansible-playbook` from the host | <http://localhost:8080> |
| `qemu/ansible` | `ansible-playbook` from the host | <http://localhost:8080> |
| `krunkit/ansible` | `ansible-playbook` from the host | <http://localhost:8080> |
| `vfkit/ansible` | `ansible-playbook` from the host | <http://localhost:8080> |
| `virtualbox/ansible` | `ansible-playbook` from the host | <http://localhost:8080> |
| `libvirt/ansible` | `ansible-playbook` from the Linux host | The VM's own address, from `make url` |
| `vagrant/virtualbox/ansible` | Vagrant's Ansible provisioner, or `ansible-playbook` from the host | <http://localhost:8080> |
| `vagrant/qemu/ansible` | Vagrant's Ansible provisioner, or `ansible-playbook` from the host | <http://localhost:8080> |
| `vagrant/avf/ansible` | `ansible-playbook` from the host; the provider can't provision | The VM's own address, from `make url` |
| `vagrant/libvirt/ansible` | Vagrant's Ansible provisioner, or `ansible-playbook` from the Linux host | <http://localhost:8080> |

`vagrant/avf/ansible` isn't fully tested: SSH to the VM failed in testing. Its README has the
details.

## What every tutorial has

- **A `web` host group.** The configuration targets `web`, and the VM is named `dev`.
- **The same make targets:**

  | Target | What it does |
  | --- | --- |
  | `make up` | Create or start the VM, without applying the configuration |
  | `make up PROVISION=true` | The same, then apply the configuration |
  | `make provision` | Apply the configuration |
  | `make verify` | `curl` the web page |
  | `make ssh` | Log into the VM |
  | `make status` | Show whether the VM is running |
  | `make halt` | Shut the VM down |
  | `make reload` | Restart the VM, without provisioning unless `PROVISION=true` |
  | `make destroy` | Delete the VM, keeping the downloaded image or box |
  | `make purge` | Delete the downloaded image or box |

  The Ansible tutorials for Vagrant that can provision through Vagrant also have
  `make playbook`, which runs `ansible-playbook` from the host instead.
- **A `mise.toml`** with `mise run deps` to install whatever is missing, `mise run versions`,
  and a task for each make target.

## Timings

[TIMINGS.md](TIMINGS.md) has the median time of each step in each tutorial, including an
estimate of how long the image or box takes to download.

To time the tutorials yourself, run:

```bash
./bench-all.sh
```

It runs `bench.sh` in each tutorial listed in `bench.yaml`, one after another, so they all
share the same connection. Each tutorial gets one cold run, which deletes the image or box
with `make purge` first so the first `make up` includes the download, and three warm runs.
Creating the VM with `make up` and provisioning it with `make provision` are timed as
separate steps.
The results go to `<name>.timings.csv`, such as `vagrant_vbox_ansible.timings.csv`, and
`bench-all.sh` then rewrites `TIMINGS.md` from them.

- **Choose tutorials** by setting `skip: true` in `bench.yaml`, or by naming them:
  `./bench-all.sh lima_ansible vagrant_vbox_ansible`.
- **Change the number of runs** with `cold_runs` and `warm_runs` in `bench.yaml`.
- **Rewrite `TIMINGS.md`** from the existing results without running anything:
  `./bench-all.sh --report`.
- **Time one tutorial** by running `bench.sh` from its folder, for example
  `cd vagrant/virtualbox/ansible && ../../../bench.sh --cold`.

Port 8080 must be free, because each tutorial serves its page there. `bench-all.sh` needs
`yq` (`brew install yq`).

## Planned

- Other configuration tools, such as Puppet, Chef and Salt
- Windows, with WSL2
