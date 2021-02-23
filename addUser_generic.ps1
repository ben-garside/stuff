Param(
    $username,
    $domain,
    $chocopackages
)

Add-LocalGroupMember -Group Administrators -Member "$domain\$username"

# Init and disks
Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false

# Install choco
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install 
choco install googlechrome, firefox, notepadplusplus, $chocopackages -y

# Add winRM
$hostname = hostname
winrm delete winrm/config/Listener?Address=*+Transport=HTTP

$c = New-SelfSignedCertificate -DnsName $hostname -CertStoreLocation cert:\LocalMachine\My
$t = $c.Thumbprint

winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$hostname`";CertificateThumbprint=`"$t`"}"
