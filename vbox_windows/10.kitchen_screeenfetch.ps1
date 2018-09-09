$path = "$home\.kitchen\cache"
# Download Archive
$url = 'https://github.com/KittyKatt/screenFetch/archive/master.zip'
$wc = New-Object System.Net.WebClient
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
$wc.DownloadFile($url, "$path\master.zip")

# Unzip Archive
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Unzip
{
  param([string]$zip, [string]$out)
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $out)
}

Unzip "$path\master.zip" "$path\
