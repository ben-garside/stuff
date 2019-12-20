Param(
    $username,
    $doamin
)

Add-LocalGroupMember -Group Administrators -Member "$domain\$username"

# Install choco
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install VS Pro
choco install visualstudio2019professional

# Install Browsers
choco install googlechrome
choco install firefox

#Install applications
choco install postman
choco install microsoftazurestorageexplorer
choco install filezilla
choco install servicebusexplorer
choco install nscp
