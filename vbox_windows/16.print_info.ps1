#!/usr/bin/env bash

"`nVirtualBox $(vboxmanage --version)`n" + `
  "$(vagrant --version)`n" + `
  "$(kitchen --version)`n" + `
  "$(docker-machine --version)`n" + `
  "$(docker --version)`n" + `
  "$(minikube version)`n" + `
  "Kubectl Client: " + `
  "$(kubectl version | Select-string "Client")".Split('"')[5] + `
  "`n"

"Current Runing VMS:"
vboxmanage list runningvms | ForEach-Object {$_.Split('"')[1]}
