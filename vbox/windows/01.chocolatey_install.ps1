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
