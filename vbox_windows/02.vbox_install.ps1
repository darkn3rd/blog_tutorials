##############################################
# Administrator Priviledge Shell ONLY
##############################################

# Helper Function
Function Update-Environment
{
  $m = [System.Environment]::GetEnvironmentVariable("Path","Machine")
  $u = [System.Environment]::GetEnvironmentVariable("Path","User")
  $env:Path = $m + ";" + $u
}

# Administrator Shell
choco install -y virtualbox
Update-Environment
