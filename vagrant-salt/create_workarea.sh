#!/usr/bin/env bash
#
# Purpose: Create structure from $HOME directory, or directory of your choosing
#

WORKAREA=${WORKAREA:-"${HOME}/vagrant-salt"}
FORMULAPATH=${WORKAREA}/roots/salt/hello_web

mkdir -p ${WORKAREA}/roots/{pillar,salt/hello_web/files}

touch ${WORKAREA}/Vagrantfile \
 ${WORKAREA}/roots/salt/top.sls \
 ${WORKAREA}/roots/pillar/{top.sls,hello_web.sls} \
 ${FORMULAPATH}/{defaults.yaml,init.sls,map.jinja,files/index.html}

cat <<-'HTML' > ${FORMULAPATH}/files/index.html
<html>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>
HTML
