#!/usr/bin/env bash
#
# Purpose: Create structure from $HOME directory, or directory of choosing
#

WORKAREA=${WORKAREA:-"${HOME}/vagrant-docker"}

mkdir -p ${WORKAREA}/{build,image}/public-html
touch ${WORKAREA}/{build,image}/Vagrantfile ${WORKAREA}/build/Dockerfile

for path in build image; do
  cat <<-'HTML' > ${WORKAREA}/${path}/public-html/index.html
<html>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>
HTML
done
