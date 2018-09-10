# Vagrant with Shell Provisioner

## Tutorial

https://medium.com/@Joachim8675309/vagrant-provisioning-e4c9fd57968d

## Instructions

You can create per blog interactively (optionally use install script to setup directory), or try out local directories here.

### Install Script

```bash
export WORKAREA=${HOME} # set to another area or use $HOME
./create_workarea
```


### Part 1 - Ubuntu

```bash
pushd part1_ubuntu
# fetch box, create guest, provision guest
vaggrant up
# test guest from host
curl -i http://127.0.0.1:8086
# cleanup
vagrant destroy --force
popd
```

### Part 2A - CentOS

```bash
pushd part2a_centos
# fetch box, create guest, provision guest
vaggrant up
# test guest from host
curl -i http://127.0.0.1:8086
# cleanup
vagrant destroy --force
popd
```

### Part 2B - Gentoo

```bash
pushd part2a_centos
# fetch box, create guest, provision guest
vaggrant up
# test guest from host
curl -i http://127.0.0.1:8086
# cleanup
vagrant destroy --force
popd
```

## License
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
