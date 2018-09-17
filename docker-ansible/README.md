# Docker Command vs Ansible Playbook Tutorial

## Mac OS X

```bash
##### Install
./helper-mac-install.sh
##### Start a VM if needed
docker-machine create --driver 'virtualbox' docker-ansible
eval $(docker-machine env docker-ansible)

##### Test Shell Ansible
./docker-wordpress.sh
curl $(docker-machine ip docker-ansible)
##### Cleanup (removes everything on this guest vm)
docker ps -q | xargs docker stop
docker ps -aq | xargs docker rm

##### Test Docker Ansible
./docker-wordpress-shell.yml
curl $(docker-machine ip docker-ansible)
##### Cleanup (removes everything on this guest vm)
docker ps -q | xargs docker stop
docker ps -aq | xargs docker rm

##### Test Docker Ansible
./docker-wordpress.yml
curl $(docker-machine ip docker-ansible)
##### Cleanup (removes everything on this guest vm)
docker ps -q | xargs docker stop
docker ps -aq | xargs docker rm

##### Stop and Remove Guest VM
docker-machine stop docker-ansible
docker-machine rm docker-ansible
