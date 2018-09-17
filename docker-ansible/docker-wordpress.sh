#!/bin/sh

# create the network if network does not exist
docker network list | grep -q "wordpress_net" || \
  docker network create "wordpress_net"

# create volumes
docker volume create -d local --name "db_data"

# start mysql database
docker run -d \
  -v db_data:/var/lib/mysql:rw \
  --network='wordpress_net' \
  --network-alias db \
  --restart=always \
  -e MYSQL_ROOT_PASSWORD='wordpress' \
  -e MYSQL_PASSWORD='wordpress' \
  -e MYSQL_USER='wordpress' \
  -e MYSQL_DATABASE='wordpress' \
  --name db mysql:5.7

# start wordpress application
docker run -d \
  --network=wordpress_net \
  --network-alias wordpress \
  -p "8080:80" \
  --restart=always \
  -e WORDPRESS_DB_HOST="db:3306" \
  -e WORDPRESS_DB_PASSWORD='wordpress' \
  --name wordpress wordpress:latest
