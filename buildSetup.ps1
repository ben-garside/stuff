Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install jdk8 -y
choco install maven -y
choco install googlechrome -y
choco install selenium-chrome-driver -y
Install-Module -Name Az -AllowClobber
