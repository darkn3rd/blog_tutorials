# Docker Command vs Ansible Playbook Tutorial

## Mac OS X

These are the commands you can use to startup and cleanup each test

```bash
##### Install
./helper-mac-install.sh
##### Start a VM if needed
docker-machine create --driver 'virtualbox' docker-compose-tutorial
eval $(docker-machine env docker-compose-tutorial)

##### Test Shell Ansible
./docker-wordpress.sh
curl $(docker-machine ip docker-compose-tutorial):8080
##### Cleanup (removes everything on this guest vm)
docker ps -q | xargs docker stop
docker ps -aq | xargs docker rm

##### Test Docker Compose
pushd compose_static
docker-compose up -d
curl $(docker-machine ip docker-compose-tutorial):8000
##### Cleanup (removes everything on this guest vm)
docker-compose stop
docker-compose rm
popd

##### Test Docker Compose
pushd compose_w_envars
docker-compose up -d
curl $(docker-machine ip docker-compose-tutorial):8000
##### Cleanup (removes everything on this guest vm)
docker-compose stop
docker-compose rm
popd

##### Stop and Remove Guest VM
docker-machine stop docker-compose-tutorial
docker-machine rm docker-compose-tutorial
