# Puppet Introduction

This tutorial covers how to get started with Puppet using Vagrant for automation some basic modules of your design.

Alternatively, you can run this manually from within the virtual machine. You would run this:

```shell
vagrant --no-provision
vagrant --provision-with "bootstrap" # install puppet agent
vagrant ssh # log into VM

# Inside VM
MODULES=$(mount | grep -o '/tmp/vagrant-puppet/modules-[^ ]*')
MANIFESTS=$(mount | grep -o '/tmp/vagrant-puppet/manifests-[^ ]*' | uniq)
puppet apply --verbose --debug \
  --modulepath "$MODULES:/etc/puppet/modules" \
 --detailed-exitcodes \
 "$MANIFESTS/default.pp"
```


# Directory Structure

You can create a similar directory structure with the following commands:

```bash
# craete directory structure
mkdir -p site/hello_web/{manifests,files} {ubuntu2204,rocky9}/manifests
# create files
touch \
 bootstrap.sh \
 site/hello_web/{manifests/init.pp,files/index.html,metadata.json} \
 {ubuntu2204,rocky9}/{manifests/default.pp,Vagrantfile}
```

This should create:

```
.
├── bootstrap.sh
├── rocky9
│   ├── Vagrantfile
│   └── manifests
│       └── default.pp
├── site
│   └── hello_web
│       ├── files
│       │   └── index.html
│       ├── manifests
│       │   └── init.pp
│       └── metadata.json
└── ubuntu2204
    ├── Vagrantfile
    └── manifests
        └── default.pp
```

# Provisioning the System

To get started, navigate to the appropriate distro directory, i.e. `rocky9` or `ubuntu2204`, and run `vagrant up`.  This will do the following:


1. Create a virtual machine, e.g. memory, vcpu, hard disk, etc.
2. Download the VM image, e.g. Rocky 9 or Ubuntu 22.04 "Jammy"
3. Start the virtual machine
4. Provision the system with shell, which installs puppet agent
5. Provision the system with Puppet

```bash
vagrant up
```

# Provisioning Manually

Alternatively, you can run this manually from within the virtual machine. You would run this.

```shell
vagrant --no-provision
vagrant --provision-with "bootstrap" # install puppet agent
vagrant ssh # log into VM
```

Then once inside the virtual machine guest, you can run the following commands:

```bash
# Inside VM
MODULES=$(mount | grep -o '/tmp/vagrant-puppet/modules-[^ ]*')
MANIFESTS=$(mount | grep -o '/tmp/vagrant-puppet/manifests-[^ ]*' | uniq)
puppet apply --verbose --debug \
  --modulepath "$MODULES:/etc/puppet/modules" \
 --detailed-exitcodes \
 "$MANIFESTS/default.pp"
```