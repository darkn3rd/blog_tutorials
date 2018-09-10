#!/usr/bin/env bash
#
# Purpose: Create structure from $HOME directory, or directory of your choosing
#

WORKAREA=${WORKAREA:-"${HOME}/vagrant-chef"}
COOKBOOK=${WORKAREA}/cookbooks/hello_web

mkdir -p ${WORKAREA}/{cookbooks,nodes}
touch ${WORKAREA}/Vagrantfile

# Create Chef Cookbook
# if command -v chef > /dev/null; then
#   pushd ${WORKAREA}/cookbooks
#   echo chef generate cookbook hello_web
#   echo chef generate attribute hello_web default
#   echo chef generate file hello_web index.html
#   popd
# else
  mkdir -p ${COOKBOOK}/{attributes,files/default,recipes}
  touch ${COOKBOOK}/{attributes,recipes}/default.rb ${COOKBOOK}/metadata.rb
#fi




cat <<-'HTML' > ${COOKBOOK}/files/default/index.html
<html>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>
HTML
