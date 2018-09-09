##############################################
# Non-Administrative Priviledge Shell ONLY
##############################################
$workarea=$home\vbox_tutorial

mkdir $workarea\cookbooks
cd $workarea\cookbooks

# Generate example
chef generate cookbook helloworld
cd helloworld
# Create Ubuntu and CentOS systems
kitchen create
