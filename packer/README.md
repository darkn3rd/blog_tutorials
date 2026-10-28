# Packer

Build a plain Ubuntu Server Vagrant box for VirtualBox, for both Apple silicon (arm64) and Intel/AMD (amd64) hosts.

### Prerequisites
- [Packer](https://developer.hashicorp.com/packer/install)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) 7.1 or later (needed for arm64 guests on Apple silicon)
- [Vagrant](https://developer.hashicorp.com/vagrant/install) 2.4 or later

---

### Build
VirtualBox can't emulate another CPU architecture, so build each box on a host of the same architecture.
There is no default for `arch` so that a build can't silently produce the wrong one.

```bash
packer init ubuntu/

# Apple silicon
packer build -var arch=arm64 ubuntu/

# Intel/AMD on Windows, Linux or macOS
packer build -var arch=amd64 ubuntu/
```

Output: `ubuntu-<version>-virtualbox-<arch>.box`.

| Variable         | Default  | Purpose                                                   |
|------------------|----------|-----------------------------------------------------------|
| `arch`           | required | `arm64` or `amd64`                                        |
| `ubuntu_version` | `26.04.1`| Release as it appears in the ISO file name                |
| `build_dir`      | `.`      | Where the build VM and the `.box` go (e.g. external drive)|
| `headless`       | `false`  | Hide the VirtualBox window during the build               |

### Try the box
```bash
vagrant box add --name ubuntu-local ubuntu-26.04.1-virtualbox-arm64.box
vagrant init ubuntu-local && vagrant up
```

---

### Layout
```
ubuntu/
├── versions.pkr.hcl    # required plugins
├── variables.pkr.hcl   # arch, ubuntu_version, build_dir, headless
├── locals.pkr.hcl      # everything that differs per architecture
├── ubuntu.pkr.hcl      # source, provisioners, vagrant post-processor
├── http/               # autoinstall data served to the installer
└── scripts/            # provision.sh, cleanup.sh
```

Ubuntu's installer is driven by [autoinstall](https://canonical-subiquity.readthedocs-hosted.com/en/latest/intro-to-autoinstall.html) (`http/user-data`), the counterpart of Fedora's kickstart.
