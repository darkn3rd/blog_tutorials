:: ::::::::::::::::::::::::::::::::::::::::
:: Previous Steps
::   vagrant ssh
:: ::::::::::::::::::::::::::::::::::::::::

:: env variables for readability
SET PSHL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
SET OPTS=-NoProfile -InputFormat None -ExecutionPolicy Bypass
SET OBJ=System.Net.WebClient
SET SCRPT='https://chocolatey.org/install.ps1'
SET CMD=iex ((New-Object %OBJ%).DownloadString(%SCRPT%))
:: install chocolatey
%PSHL% %OPTS% -Command "%CMD%"
:: setup local path
SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
:: install msys2 package
choco install -y msys2
:: run the bash shell
c:\tools\msys64\usr\bin\bash.exe
