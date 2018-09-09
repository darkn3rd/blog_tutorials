##############################################
# Non-Administrative Priviledge Shell ONLY
##############################################

# Create a docker machine environment called default
docker-machine create --driver virtualbox 'default'

# Tell docker engine to use machine's docker (defaulting to default)
& docker-machine env default | Invoke-Expression

# Run a container fetched from docker hub
docker run docker/whalesay cowsay Hello World
