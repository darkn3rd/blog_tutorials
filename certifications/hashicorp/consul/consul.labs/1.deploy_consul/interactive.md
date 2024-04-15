

# Bastion Host Tab

```bash
# https://github.com/hashicorp-education/learn-consul-get-started-vms
export CONSUL_DATACENTER="dc1" \
export CONSUL_DOMAIN="consul" \
export CONSUL_DATA_DIR="/opt/consul" \
export CONSUL_CONFIG_DIR="/etc/consul.d/"
export CONSUL_RETRY_JOIN="consul-server-0"

export OUTPUT_FOLDER="./assets/scenario/conf/"
mkdir -p ${OUTPUT_FOLDER}

./ops/scenarios/99_supporting_scripts/generate_consul_server_config.sh 
tree ${OUTPUT_FOLDER}  

consul validate ${OUTPUT_FOLDER}/consul-server-0

export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/
ssh -i certs/id_rsa consul-server-0 "sudo rm -rf ${CONSUL_REMOTE_CONFIG_DIR}*"

# NOTE: 
#  'scp' no longer works on Debian 12 (Bookworm)
#
# Background
#  * default location for sftp is /usr/libexec/sftp-server
#  * new location for sftp is /usr/lib/openssh/sftp-server
#  * new location not configured in /etc/ssh/ssh_config
# Links
#  * https://www.baeldung.com/linux/openssh-internal-sftp-vs-sftp-server
# Workaround
#   * update '/etc/ssh/ssh_config' with 'Subsystem sftp /usr/lib/openssh/sftp-server'
#   * use 'scp -O' for legacy SCP protocol instead of SFTP protocol

scp -i certs/id_rsa -O ${OUTPUT_FOLDER}consul-server-0/* consul-server-0:${CONSUL_REMOTE_CONFIG_DIR}
```

# Consul Tab


```bash
consul agent -config-dir=/etc/consul.d > /tmp/consul-server.log 2>&1 &
cat /tmp/consul-server.log

```