#!/usr/bin/env bash
WORKAREA=${HOME}/vbox_tutorial


######## vagrant w/ gentoo linux cleanup ########
cd ${WORKAREA}
cd mygentoo
vagrant halt     # stop running vm guest
vagrant destroy  # delete vm guest entirely

######## vagrant w/ archlinux cleanup ########
cd ${WORKAREA}
cd myarch
vagrant halt     # stop running vm guest
vagrant destroy  # delete vm guest entirely

######## testkitchen cleanup ########
cd ${WORKAREA}/cookbooks/helloworld
kitchen destroy # destroys all test systems

######## minkube cleanup ########
minikube stop # stop kubernetes cluster
minikube rm   # remove vm hosting cluster and kubectl config entries

######## dockermachine cleanup ########
docker-machine stop       # stop vm hosting docker
docker-machine rm default # remove vm entirely
