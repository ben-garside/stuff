param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$AgentName,
    [parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$AgentFileName,
    [parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$OrganizationName,
    [parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$Pat,
    [parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$Pool
)

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install jdk8 -y
choco install maven -y
choco install googlechrome -y
choco install selenium-chrome-driver -y
Install-Module -Name Az -AllowClobber -Force

$Zipfile = $AgentFileName +".zip"
if (Test-Path "C:\Temp\$AgentFileName") {

}
else {
    New-Item -Path C:\ -Name Temp -ItemType "directory"
    $regex = $AgentFileName -match '\d\.\d*\.\d'
    $Version = $Matches[0]
    $url = "https://vstsagentpackage.azureedge.net/agent/$Version/$AgentFileName.zip"
    $output = "C:\Temp\$ZipFile"
    $Download = New-Object System.Net.WebClient
    $Download.DownloadFile($url, $output)
    Expand-Archive -LiteralPath "C:\temp\$ZipFile" -DestinationPath "C:\Temp\$AgentFileName" -Force
}
Set-Location "C:\Temp\$AgentFileName"

& .\config.cmd --unattended --url https://dev.azure.com/$OrganizationName --auth pat --token $pat --pool $pool --agent $agentname --replace --runAsService
