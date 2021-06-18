##############################################
# Administrator Priviledge Shell ONLY
##############################################
Function Update-Environment
{
  $m = [System.Environment]::GetEnvironmentVariable("Path","Machine")
  $u = [System.Environment]::GetEnvironmentVariable("Path","User")
  $env:Path = $m + ";" + $u
}

choco install -y docker-toolbox
Update-Environment
