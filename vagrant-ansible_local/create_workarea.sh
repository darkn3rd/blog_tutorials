#!/usr/bin/env bash
#
# Purpose: Create structure from $HOME directory, or directory of your choosing
#

WORKAREA=${WORKAREA:-"${HOME}/vagrant-ansible"}
ROLEPATH=${WORKAREA}/provision/roles/hello_web

# Create Ansible Role
if command -v ansible-galaxy > /dev/null; then
  ansible-galaxy init ${ROLEPATH}
else
  mkdir -p ${ROLEPATH}/{defaults,files,tasks}
  touch ${ROLEPATH}/{defaults/main.yml,tasks/main.yml,files/index.html}
fi

cat <<-'HTML' > ${ROLEPATH}/files/index.html
<html>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>
HTML
