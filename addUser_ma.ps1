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

#### FUNCTIONS ####

function install-msi{
    Param(
        $msi
    )
    write-host "Installing $msi"
    $p = [Diagnostics.Process]::Start($msi,'/quiet') 
    $p.WaitForExit()
    write-host "Installed $msi Exit: $($p.ExitCode)"
}

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

write-host "#### START"
$poop = "sv=2021-06-08&ss=b&srt=o&sp=rlx&se=2032-07-14T18:08:39Z&st=2022-07-14T10:08:39Z&spr=https&sig="
$sas = "$poop$sas"

write-host "#### Adding user to admin group"
$AdminGroup = [ADSI]"WinNT://$env:computername/Administrators,group"
$User = [ADSI]"WinNT://$domain/$username,user"
$AdminGroup.Add($User.Path)

# Init and disks
write-host "#### Init disk and assigning Drive letter"
Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -DriveLetter F -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false

# Add windows features
write-host "#### Adding windows features"
add-windowsfeature Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Performance, Web-Stat-Compression, Web-Dyn-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-Asp-Net, Web-Asp-Net45, Web-Mgmt-Tools, Web-Mgmt-Console, NET-WCF-HTTP-Activation45

# Install choco
write-host "#### Installing Choco"
if([System.Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12)){
    Write-Host "TLS 1.2 active"
} else {
    Write-Host "TLS 1.2 NOT ACTIVE, ACTIVATING NOW..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

write-host "#### Installing Apps via choco"
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
write-host "#### Setting AAR"
Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.webServer/proxy" -name "enabled" -value "True"

# Disable IE ESC
write-host "#### Disabling IE ESC"
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
Stop-Process -Name Explorer

# Create folders
write-host "#### Creating folders"
New-Item -Path "F:\" -Name "Projects" -ItemType "directory" -Force
New-Item -Path "F:\" -Name "SQL" -ItemType "directory" -Force
New-Item -Path "F:\SQL" -Name "Data" -ItemType "directory" -Force
New-Item -Path "F:\SQL" -Name "Log" -ItemType "directory" -Force
New-Item -Path "F:\SQL" -Name "Backups" -ItemType "directory" -Force

# Get db backups
write-host "#### Getting DB backups"
$url = "$blob/$dbContainer"
Invoke-BlobItems -uri $url -sas $sas -Path $path
$url = "$blob/$vmContainer"
Invoke-BlobItems -uri $url -sas $sas -Path $path

# Rename backups
write-host "#### Tidying DB names"
$files = Get-ChildItem -Path $path -Filter *.bak
$regex = "(.*_)(.*)(_.*)"

# Update SQL auth mode to Mixed via REG and restart the service
write-host "#### Updating SQL login mode"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQLServer" -Name LoginMode -Value 2
Restart-Service -Name MSSQLSERVER
sleep 10
while((Get-Service -Name MSSQLSERVER).Status -ne 'running'){
    write-host "# sleeping... "
    sleep 10
}

# Add SQL user
write-host "#### Adding local SQL user"
$command = 
@"
Invoke-Sqlcmd -Query "CREATE LOGIN [$dbUser] WITH PASSWORD=N'$dbPassword', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF; EXEC master..sp_addsrvrolemember @loginame = N'$dbUser', @rolename = N'sysadmin'"
"@

$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encodedCommand = [Convert]::ToBase64String($bytes)
$securePassword = ConvertTo-SecureString $localAdminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential "\$LocalAdminUser", $securePassword
Start-Process powershell.exe  -Credential $credential -ArgumentList ("-encodedCommand $encodedCommand")

# Install EpiServer
write-host "#### Installing EPISERVER"
$epiPath = 'F:\SQL\Backups\EPI'
7z e 'F:\SQL\Backups\EPiServer 7.5.394.2.7z' -o"$epiPath" -r -y
cd $epiPath
$msis = Get-ChildItem -Path $epiPath -Filter *.msi
foreach($msi in $msis){
   install-msi "$epiPath\$msi"
}

# Restore DBs
write-host "#### Restoring Databases"
$sqlrestore = "$blob/$vmContainer/restore.txt?$sas"
$sqlcommand = (Invoke-webrequest -URI $sqlrestore -UseBasicParsing).Content
Invoke-Sqlcmd -Query $sqlcommand -Username "$dbUser" -Password "$dbPassword" -ConnectionTimeout 0 -QueryTimeout 0

write-host "#### END"

