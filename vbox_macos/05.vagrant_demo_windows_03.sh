##############################################
# Previous Steps
#   vagrant ssh
#   c:\tools\msys64\usr\bin\bash.exe
##############################################

# install unzip package
PATH=/usr/bin:$PATH
pacman -S unzip

# install screenfetch
URL=https://github.com/KittyKatt/screenFetch/archive/master.zip
curl -OL $URL
unzip master.zip

# run screenfetch
./screenFetch-master/screenfetch-dev
