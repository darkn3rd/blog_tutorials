These were tested in the following environments:

* Macbook Pro
  **Processor**: Intel(R) Core(TM) i5-1038NG7 CPU @ 2.00GHz
  **Operating System**: macOS 12.2.1 (Darwin Kernel Version 21.3.0)
  * Vagrant 2.4.1
    * Provider:
      * `virtualbox`: Virtualbox 7.0.18
      * `qemu` (vagrant-qemu 0.3.6): QEMU 9.0.0
    * Box
      * `generic/ubuntu2204` (`virtualbox`, 4.3.12, (amd64))



## Notes


### macOS

```bash
sysctl -a | grep brand_string
qemu-system-x86_64 --version
vboxmanage --version
vagrant --version
vagrant box list
vagrant plugin list
uname -a
sw_vers
```