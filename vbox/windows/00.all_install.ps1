##############################################
# Administrator Priviledge Shell ONLY
##############################################

# Set privilege for running scripts
Set-ExecutionPolicy Bypass -Scope Process -Force
# variables for readibility
$scripturl = 'https://chocolatey.org/install.ps1'
$wc = New-Object System.Net.WebClient
# Install Chocolately
Invoke-Expression ($wc.DownloadString($scripturl))


# Install All the Packages

@'
<?xml version="1.0" encoding="utf-8"?>
<packages>
  <package id="virtualbox" />
  <package id="vagrant" />
  <package id="chefdk" />
  <package id="docker-toolbox" />
  <package id="kubernetes-cli" />
  <package id="minikube" />
</packages>
'@ | Out-File -Encoding "UTF8" choco.config

choco install -y choco.config
