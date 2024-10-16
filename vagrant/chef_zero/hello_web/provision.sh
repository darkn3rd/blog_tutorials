#############
# Find mounted directories for Chef Cookbooks and Nodes
##########################
COOKBOOK_PATH=$(mount | grep -o /tmp.*/cookbooks | uniq)
NODE_PATH=$(mount | grep -o /tmp.*/node | uniq)

#############
# Construct client configuration
##########################
cat << EOF > /tmp/client.rb
cookbook_path ["$COOKBOOK_PATH"]
role_path []
log_level :debug
verbose_logging false
enable_reporting false
encrypted_data_bag_secret nil
data_bag_path []
chef_zero.enabled true
local_mode true
node_path ["$NODE_PATH"]
EOF

#############
# Construct override attributes with run list
##########################
if grep -q rocky /etc/os-release; then
  # configure using override attributes for Rocky Linux
  cat << 'EOF' > /tmp/dna.json
{
  "hello_web": {
    "package": "httpd",
    "service": "httpd",
    "docroot": "/var/www/html"
  },
  "run_list": [
    "recipe[hello_web]"
  ]
}
EOF
else
  # confgiure using default attributes
  cat << 'EOF' > /tmp/dna.json
{
  "run_list": [
    "recipe[hello_web]"
  ]
}
EOF
fi

#############
# Provision the system
##########################
sudo chef-client \
  --config /tmp/client.rb \
  --json-attributes /tmp/dna.json \
  --local-mode \
  --force-formatter \
  --chef-license "accept-silent"

#############
# Logout when finished
##########################
logout
