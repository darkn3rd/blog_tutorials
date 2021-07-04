##############################################
# Non-Administrative Priviledge Shell ONLY
##############################################
$workarea=$home\vbox_tutorial
mkdir $workarea

mkdir $workarea\mymanjaro
cd $workarea\mymanjaro

vagrant init mloskot/manjaro-i3-17.0-minimal
vagrant up

# Download and Install ScreenFetch on virtual guest
$url = 'https://github.com/KittyKatt/screenFetch/archive/master.zip'
vagrant ssh --command "curl -OL $url"
vagrant ssh --command 'sudo pacman -S unzip'
vagrant ssh --command 'unzip master.zip'
vagrant ssh --command './screenFetch-master/screenfetch-dev'
