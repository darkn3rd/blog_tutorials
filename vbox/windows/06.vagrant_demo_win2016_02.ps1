##############################################
# ONLY RUN ON Virtual Guest
#  Run First:
#   cd $home\vbox_tutorial/mywindows
#   vagrant powershell
##############################################

Function Update-Environment
{
  $m = [System.Environment]::GetEnvironmentVariable("Path","Machine")
  $u = [System.Environment]::GetEnvironmentVariable("Path","User")
  $env:Path = $m + ";" + $u
}

Set-ExecutionPolicy Bypass -Scope Process -Force
$scripturl = 'https://chocolatey.org/install.ps1'
$wc = New-Object System.Net.WebClient
Invoke-Expression ($wc.DownloadString($scripturl))
Update-Environment

choco install -y bitvise-ssh-server
Start-Service BvSshServer
choco install -y msys2
