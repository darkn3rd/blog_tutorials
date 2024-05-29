

# Virtual Guest 

This should support [Virtualbox](https://www.virtualbox.org/) on macOS, Linux, or Windows.  Also [QEMU](https://www.qemu.org/) using [HVF](https://developer.apple.com/documentation/hypervisor) accelerator is supported on macOS on both Intel (x86_64) and Apple Silicon (ARM64).

## Vagrant Installation

Overview of downloading and installing [Vagrant](https://www.vagrantup.com/) is here:

* [Documentation: Install Vagrant](https://developer.hashicorp.com/vagrant/docs/installation) 
* [Developer: Install Vagrant](https://developer.hashicorp.com/vagrant/install)

### Vagrant: macOS 

If you have Homebrew, you can install [Vagrant](https://www.vagrantup.com/) with the following:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/hashicorp-vagrant
```

### Vagrant: Windows

On Windows, if you have [Chocolatey](https://chocolatey.org/install), you can install [Vagrant](https://www.vagrantup.com/) with the following:

```PowerShell
# https://community.chocolatey.org/packages/vagrant
choco install vagrant
```

For using Virtualbox:

* On Windows 10, disable Hyper-V before running Virtualbox:
  ```PowerShell
  Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
  ```
* On Windows, 11, disable Hyper-V before running Virtualbox:
  ```PowerShell
  bcdedit /set hypervisorlaunchtype off
  ```

### Vagrant; Linux (Ubuntu/Debian)

You can install Vagrant using the following:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant
```

## Virtualbox Installation

If you wish to use [Virtualbox](https://www.virtualbox.org/) with [Vagrant](https://www.vagrantup.com/), here's some notes below:

### Virtualbox: macOS 

If you have Homebrew, you can install Vagrant with the following:

```bash
# https://formulae.brew.sh/cask/virtualbox
brew install virtualbox
```

### Vagrant: Windows

On Windows, if you have [Chocolatey](https://chocolatey.org/install), you can install Vagrant with the following:

```PowerShell
# https://community.chocolatey.org/packages/virtualbox
choco install virtualbox
```

### Virtualbox: Linux (Ubuntu/Debian)

For Virtualbox, if problems are encountered, you can KVM to the denylist:

```bash
echo 'blacklist kvm-intel' >> /etc/modprobe.d/blacklist.conf
```

Instructions for installing [Virtualbox](https://www.virtualbox.org/), such as kernel modules and such is here:

* [2.3. Installing on Linux Hosts](https://www.virtualbox.org/manual/ch02.html#install-linux-host)

## QEMU with HVF Installation

On macOS, you can install QEMU and the vagrant plugin with the following

```bash
brew install qemu
vagrant plugin install vagrant-qemu
```

## Using Virtualguest

The configuration file (`Vagrantfile`) is written for either [Virtualbox](https://www.virtualbox.org) or [QEMU](https://www.qemu.org/) with HVF accelerator.

For QEMU, run `vagrant up --provider qemu`, otherwise for the default Virtualbox, run `vagrant up`.
