##############################################
# Non-Administrative Priviledge Shell ONLY
##############################################
$workarea=$home\vbox_tutorial

######## vagrant w/ manjaro cleanup ########
cd $workarea\mymanjaro
vagrant halt     # stop running vm guest
vagrant destroy  # delete vm guest entirely

######## vagrant w/ win2016 cleanup ########
cd $workarea\mywindows
vagrant halt     # stop running vm guest
vagrant destroy  # delete vm guest entirely

######## testkitchen cleanup ########
cd $workarea\cookbooks\helloworld
kitchen destroy # destroys all test systems

######## minkube cleanup ########
minikube stop # stop kubernetes cluster
minikube rm   # remove vm hosting cluster and kubectl config entries

######## dockermachine cleanup ########
docker-machine stop       # stop vm hosting docker
docker-machine rm default # remove vm entirely
