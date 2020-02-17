Param(
    $username,
    $domain,
    $path = "f:\SQL\backups",
    $dbUser,
    $dbPassword,
    $localAdminUser,
    $localAdminPassword,
    $sas,
    $blob,
    $dbContainer = "dev-vm-ma-sql",
    $vmContainer = "dev-vm-assests"
)


$poop = "sv=2019-02-02&ss=b&srt=sco&sp=rl&se=2021-01-09T16:44:05Z&st=2020-01-09T08:44:05Z&spr=https&sig="
$sas = "$poop$sas"

add-content -Path d:\env.txt -Value "--------"
add-content -Path d:\env.txt -Value "Username: $username"
add-content -Path d:\env.txt -Value "domain: $domain"
add-content -Path d:\env.txt -Value "dbUser: $dbUser"
add-content -Path d:\env.txt -Value "dbPassword: $dbPassword"
add-content -Path d:\env.txt -Value "path: $path"
add-content -Path d:\env.txt -Value "localAdminUser: $localAdminUser"
add-content -Path d:\env.txt -Value "localAdminPassword: $localAdminPassword"
add-content -Path d:\env.txt -Value "sas: $sas"
add-content -Path d:\env.txt -Value "blob: $blob"
add-content -Path d:\env.txt -Value "dbContainer: $dbContainer"
Add-Content -Path d:\env.txt -Value "vmContainer: $vmContainer"

$AdminGroup = [ADSI]"WinNT://$env:computername/Administrators,group"
$User = [ADSI]"WinNT://$domain/$username,user"
$AdminGroup.Add($User.Path)

# Init and disks
Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -DriveLetter F -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false

# Add windows features
add-windowsfeature Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Performance, Web-Stat-Compression, Web-Dyn-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-Asp-Net, Web-Asp-Net45, Web-Mgmt-Tools, Web-Mgmt-Console, NET-WCF-HTTP-Activation45

# Install choco

if([System.Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12)){
    Write-Host "TLS 1.2 active"
} else {
    Write-Host "TLS 1.2 NOT ACTIVE, ACTIVATING NOW..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

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
choco install 7zip.install -y

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
New-Item -Path "F:\SQL" -Name "Log" -ItemType "directory" -Force
New-Item -Path "F:\SQL" -Name "Backups" -ItemType "directory" -Force

# Get databases
function Invoke-BlobItems {  
    param (
        [Parameter(Mandatory)]
        [string]$uri,
        [Parameter(Mandatory)]
        [string]$sas,
        [string]$Path = (Get-Location)
    )

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
$url = "$blob/$dbContainer"
Invoke-BlobItems -uri $url -sas $sas -Path $path

$url = "$blob/$vmContainer"
Invoke-BlobItems -uri $url -sas $sas -Path $path

# Rename backups
$files = Get-ChildItem -Path $path -Filter *.bak
$regex = "(.*_)(.*)(_.*)"

# Update SQL auth mode to Mixed via REG and restart the service
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQLServer" -Name LoginMode -Value 2
Restart-Service -Name MSSQLSERVER
while((Get-Service -Name MSSQLSERVER).Status -ne 'running'){
    sleep 10
}

# Add SQL user
$command = 
@"
Invoke-Sqlcmd -Query "CREATE LOGIN [$dbUser] WITH PASSWORD=N'$dbPassword', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF; EXEC master..sp_addsrvrolemember @loginame = N'$dbUser', @rolename = N'sysadmin'"
"@

$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encodedCommand = [Convert]::ToBase64String($bytes)
$securePassword = ConvertTo-SecureString $localAdminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential "\$LocalAdminUser", $securePassword
Start-Process powershell.exe  -Credential $credential -ArgumentList ("-encodedCommand $encodedCommand")
