<#
.Synopsis
Simple script to download Bitdefender Endpoint installer from GravityZone and install on device.
Supports using Ninja RMM Custom Field to specify download URL
Get setupdownloader URL from GravityZone -> Network -> Installation Packages -> select checkbox for installer -> SEND DOWNLOAD LINKS

Existing install detection: Checks for a Windows Service (name specified below as $bdServiceName). Exit with code 1 if found.

.Example
.\Install-Bitdefender.ps1 -InstallerURL "https://cloudgz.gravityzone.bitdefender.com/Packages/BSTWIN/0/setupdownloader_[...==].exe"
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [String]$InstallerURL,
    [Parameter()]
    [string]$CustomFieldName = 'bitdefenderInstallerUrl'
)
# Variables
# Ninja script variable overrides
if ($customFieldValue = Get-NinjaProperty -Name $CustomFieldName) {$InstallerURL = $customFieldValue}
if ([string]::IsNullOrWhiteSpace($InstallerURL)) {
    Write-Host '[ERROR] Installer URL not specified. Exiting with error.'
    exit 1
}

# File paths
$downloadFolder = 'C:\5SBS\Bitdefender'            # Temp folder for downloaded installer
$installerName  = Split-Path $InstallerURL -Leaf   # Installer file name
$installerPath  = "$downloadFolder\$installerName" # Installer full path

# Operational vars
$bdServiceName  = 'Bitdefender Endpoint Protected Service'
$exitCode       = 0

# Begin
# Check if Bitdefender is already installed
$bdService = Get-Service | Where-Object {$_.DisplayName -eq $bdServiceName}
if ($null -ne $bdService) {
    Write-Output "[ERROR] Detected Bitdefender service `"$bdServiceName`" - is Bitdefender already installed?"
    Write-Output '[ERROR] Exiting with error.'
    exit 1
}

# Download installer from GravityZone
Write-Output "[INFO] Downloading Bitdefender installer: $installerName"
if (!(Test-Path $downloadFolder)) {
    New-Item -ItemType Directory -Path $downloadFolder | Out-Null
}
try {
    Invoke-WebRequest -Uri $InstallerURL -OutFile ($tempFile = New-TemporaryFile) -Method Get
    Move-Item -LiteralPath $tempFile -Destination $installerPath -Force
    Write-Output '[INFO] Download complete'
} catch {
    Write-Output '[ERROR] Download failed! Exiting with error'
    exit 1
}

# Run installer
Write-Output "[INFO] Running install: $installerPath"
$process = Start-Process $installerPath -PassThru -Wait
$exitCode = $process | Select-Object -ExpandProperty ExitCode
Write-Output "[INFO] Installer finished running -- exit code $exitCode"

# Delete downloaded files
Write-Output '[INFO] Tidying files'
Remove-Item -Path $downloadFolder -Recurse

Write-Output "[INFO] Finished! Exiting with code $exitCode"
exit $exitCode