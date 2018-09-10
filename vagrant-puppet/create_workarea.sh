#!/usr/bin/env bash
#
# Purpose: Create structure from $HOME directory, or directory of your choosing
#

WORKAREA=${WORKAREA:-"${HOME}/vagrant-puppet"}
MODULE=${WORKAREA}/site/hello_web

mkdir -p ${WORKAREA}/{site,manifests} \
  ${WORKAREA}/site/hello_web/{files,manifests}

touch ${WORKAREA}/{Vagrantfile,bootstrap.sh} \
 ${WORKAREA}/manifests/default.pp \
 ${WORKAREA}/site/hello_web/manifests/init.pp

cat <<-'HTML' > ${MODULE}/files/index.html
<html>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>
HTML
