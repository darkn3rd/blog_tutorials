##############################################
# Non-Administrative Priviledge Shell ONLY
##############################################

# Start minikube environment
minikube start --vm-driver=virtualbox
# Deploy Something
kubectl run hello-minikube `
  --image=k8s.gcr.io/echoserver:1.4 `
  --port=8080
kubectl expose deployment hello-minikube `
  --type=NodePort


# Loop Until Available
# kubectl get pod

$url = & minikube service hello-minikube --url
(New-Object System.Net.WebClient).DownloadString($url)
