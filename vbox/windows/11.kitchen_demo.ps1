##############################################
# Non-Administrative Priviledge Shell ONLY
##############################################
$workarea=$home\vbox_tutorial
cd $workarea\cookbooks\helloworld

# Install pciutils on CentOS (required by screenfetch)
kitchen exec centos --command='sudo yum -y install pciutils'
# Install a snap on Ubuntu (avoids warnings w/ screenfetch)
kitchen exec ubuntu --command='sudo snap install hello-world'

# Run screenfetch script on all systems
kitchen exec default* `
 --command='sudo /tmp/omnibus/cache/screenFetch-master/screenfetch-dev'
