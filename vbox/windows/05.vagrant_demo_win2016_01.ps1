##############################################
# Non-Administrative Priviledge Shell ONLY
##############################################
$workarea=$home\vbox_tutorial

##############################################
# Prerequisites: Windows2016 Image
#   See: https://github.com/mwrock/packer-templates
##############################################

# add recently build vagrant box to Vagrant (path varies)
$winboxpath = 'path\to\windows2016min-virtualbox.box'
vagratbox add $winboxpath --name 'my/win2016'
# create staging area
mkdir $workarea\mywindows
cd $workarea\mywindows
# create local copy and start instance
vagrant init my/win2016
vagrant up
