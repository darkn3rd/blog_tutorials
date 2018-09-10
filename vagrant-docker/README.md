# Vagrant with Docker Provisioner

## Tutorial

https://medium.com/@Joachim8675309/vagrant-provisioning-with-docker-3621df12092a

## Instructions

You can create per blog interactively (optionally use install script to setup directory), or try out local directories here.

### Install Script

```bash
export WORKAREA=${HOME} # set to another area or use $HOME
./create_workarea
```


### Part 1 - Build Docker Image

```bash
pushd part1_build
# fetch box, create guest, provision guest
vaggrant up
# test guest from host
curl -i http://127.0.0.1:8081
# cleanup
vagrant destroy --force
popd
```

### Part 2A - Using Existing Image

```bash
pushd part1_image
# fetch box, create guest, provision guest
vaggrant up
# test guest from host
curl -i http://127.0.0.1:8081
# cleanup
vagrant destroy --force
popd
```

## License
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
