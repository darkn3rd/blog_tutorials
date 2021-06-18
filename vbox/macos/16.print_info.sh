#!/usr/bin/env bash

printf "\nVirtualBox %s\n" $(vboxmanage --version) && \
 vagrant --version && \
 kitchen --version && \
 docker-machine --version && \
 docker --version && \
 minikube version && \
 printf "Kubectl Client: %s\n" \
   $(kubectl version | awk -F\" \
    '/Client/{ print $6 }')

printf "Currently Running VMS:\n"
for VMS in $(vboxmanage list runningvms | cut -d'"' -f2); do
  printf "  * %s\n" ${VMS}
done
