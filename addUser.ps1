Param(
    $username,
    $doamin
)

Add-LocalGroupMember -Group Administrators -Member "$domain\$username"

# Init and disks
powershell -Command Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false

# Install choco
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install VS Pro
choco install visualstudio2019professional -y

# Install Browsers
choco install googlechrome -y
choco install firefox -y

#Install applications
choco install postman -y
choco install microsoftazurestorageexplorer -y
choco install filezilla -y
choco install servicebusexplorer -y
choco install nscp -y
