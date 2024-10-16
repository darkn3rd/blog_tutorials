# Hello Web Example (chef_zero)

This is a basic example that demonstrates how to use an internal Cookbook and Vagrant with the Chef Zero, and in-memory Chef Server.

Releated Article:
  * [Cooking with Chef on Vagrant](https://medium.com/@joachim8675309/cooking-with-chef-on-vagrant-fd5264569448)

## Directory Structure

You can create a similar directory structure with the following commands:

```bash
PROJ_HOME=.

# craete directory structure
mkdir -p \
  $PROJ_HOME/cookbooks/hello_web/{attributes,files/default,recipes} \
  $PROJ_HOME/{ubuntu2204,rocky9}/nodes

cd $PROJ_HOME

touch \
 ./cookbooks/hello_web/{attributes,recipes}/default.rb \
 ./cookbooks/hello_web/files/default/index.html \
 ./{ubuntu2204,rocky9}/Vagrantfile
```

This will create the following directory structure in `$PROJ_HOME`:

```
.
├── README.md
├── cookbooks
│   └── hello_web
│       ├── attributes
│       │   └── default.rb
│       ├── files
│       │   └── default
│       │       └── index.html
│       └── recipes
│           └── default.rb
├── rocky9
│   ├── Vagrantfile
│   └── nodes
└── ubuntu2204
    ├── Vagrantfile
    └── nodes
```

# Provisioning the System

To get started, navigate to the appropriate distro directory, i.e. `rocky9` or `ubuntu2204`, and run `vagrant up`.  This will do the following:


1. Create a virtual machine, e.g. memory, vcpu, hard disk, etc.
2. Download the VM image, e.g. Rocky 9 or Ubuntu 22.04 "Jammy"
3. Start the virtual machine
4. Provision the system with Chef Zero after installing Chef.

```bash
vagrant up
```

# Provisioning Manually

Alternatively, you can run this manually from within the virtual machine. You would run this.

```shell
vagrant up --no-provision
vagrant ssh # log into VM
```

Then once inside the virtual machine guest, you can run the following commands:

```bash
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
```