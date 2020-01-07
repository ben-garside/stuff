Param(
    $username,
    $doamin
)

Add-LocalGroupMember -Group Administrators -Member "$domain\$username"

# Init and disks
Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false

# Install choco
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Browsers
choco install googlechrome -y
choco install firefox -y

#Install applications
choco install microsoftazurestorageexplorer -y
choco install filezilla -y
choco install nscp -y
choco install notepadplusplus --force -y
