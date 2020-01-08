Param(
    $username,
    $domain,
    $blob,
    $path = "f:\SQL\backups"
)

$AdminGroup = [ADSI]"WinNT://$env:computername/Administrators,group"
$User = [ADSI]"WinNT://$domain/$username,user"
$AdminGroup.Add($User.Path)

# Init and disks
Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false

# Add windows features
add-windowsfeature Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Performance, Web-Stat-Compression, Web-Dyn-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-Asp-Net, Web-Asp-Net45, Web-Mgmt-Tools, Web-Mgmt-Console, NET-WCF-HTTP-Activation45

# Install choco
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install VS Pro
choco install visualstudio2019professional -y
choco install classic-shell -y

# Install Browsers
choco install googlechrome -y
choco install firefox -y

#Install applications
choco install microsoftazurestorageexplorer -y
choco install filezilla -y
choco install nscp -y
choco install notepadplusplus --force -y
choco install winmerge -y

# IIS stuff
choco install iis-arr --force -y
choco install urlrewrite --force -y

# AAR
Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.webServer/proxy" -name "enabled" -value "True"

# Disable IE ESC
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
Stop-Process -Name Explorer

# Create folders
New-Item -Path "F:\" -Name "Projects" -ItemType "directory" -Force
New-Item -Path "F:\" -Name "SQL" -ItemType "directory" -Force
New-Item -Path "F:\SQL" -Name "Data" -ItemType "directory" -Force
New-Item -Path "F:\SQL" -Name "Logs" -ItemType "directory" -Force
New-Item -Path "F:\SQL" -Name "Backups" -ItemType "directory" -Force

# Get databases
function Invoke-BlobItems {  
    param (
        [Parameter(Mandatory)]
        [string]$URL,
        [string]$Path = (Get-Location)
    )

    $uri = $URL.split('?')[0]
    $sas = $URL.split('?')[1]

    $newurl = $uri + "?restype=container&comp=list&" + $sas 

    #Invoke REST API
    $body = Invoke-RestMethod -uri $newurl

    #cleanup answer and convert body to XML
    $xml = [xml]$body.Substring($body.IndexOf('<'))

    #use only the relative Path from the returned objects
    $files = $xml.ChildNodes.Blobs.Blob.Name
 

    #create folder structure and download files
    $files | ForEach-Object { $_; New-Item (Join-Path $Path (Split-Path $_)) -ItemType Directory -ea SilentlyContinue | Out-Null
        (New-Object System.Net.WebClient).DownloadFile($uri + "/" + $_ + "?" + $sas, (Join-Path $Path $_))
     }
}

# Get db backups
Invoke-BlobItems -URL $blob  -Path $path

# Rename backups
$files = Get-ChildItem -Path $path -Filter *.bak
$regex = "(.*_)(.*)(_.*)"

foreach($file in $files){
    $file -match $regex | Out-Null
    Rename-Item -Path "$path\$file" -NewName "$($matches[2]).bak"
}

# Update SQL auth mode to Mixed via REG and restart the service
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQLServer" -Name LoginMode -Value 2
Restart-Service -Name MSSQLSERVER
while((Get-Service -Name MSSQLSERVER).Status -ne 'running'){
    sleep 2
}
