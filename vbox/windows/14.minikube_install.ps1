##############################################
# Administrator Priviledge Shell ONLY
##############################################
Function Update-Environment
{
  $m = [System.Environment]::GetEnvironmentVariable("Path","Machine")
  $u = [System.Environment]::GetEnvironmentVariable("Path","User")
  $env:Path = $m + ";" + $u
}

# Install MiniKube and Kubernetes-CLI dependency
choco install -y minikube
Update-Environment
