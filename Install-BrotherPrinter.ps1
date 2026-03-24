<#
.Synopsis

Simple script to download and install a Brother printer from .MSI ripped from interactive installer.
Reference video:  https://www.youtube.com/watch?v=nC3qCWt6Oe4

Install:
powershell.exe -executionpolicy bypass -file .\Install-BrotherPrinter.ps1 -RepoFolderName "Brother MFC-L8690CDW" -PrinterFriendlyName "Admin Printer" -PrinterIP "192.168.1.5" -MSI "PrintDriver.msi"

Detection:
HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Print\Printers\Admin Printer
Name = "Admin Printer"

Deploying drivers to client:
1. Download and run interactive installer from Brother and get extracted files. Brother dumps them here: Program Files (x86)\Brother\<Extracted (folder name timestamp of installer runtime)>
   Files required:
   - Print driver MSI        # <Extracted>\Install\Msi\brprc16a.msi)
   - Printer metadata file   # <Extracted>\Install\model\model003.dat)
2. Identify the two files you'll need:
   - Print driver MSI:       .MSI file properties -> Details -> Comments -> "This installer database contains the logic and data required to install Brother Printer Driver."
   - Printer metadata file:  Open model<nnn>.dat file in Notepad -> check [Model]->ModelName
3. Copy those two files to their own folder
######### Continue doco below here (the below text is copied from the .INF install script, not applicable for this install script)
4. After naming the folder correctly, compress it to a .zip file. Folder structure should be as follows:
    Driver Name.zip         -> Driver Name Folder  \driver.inf
    RICOH MP C3003 PCL6.zip -> RICOH MP C3003 PCL6 \MPC3003_.inf
5. Create new NinjaOne "File transfer" Automation for this printer driver. Naming convention:
    5SBS - Printer Drivers - Manufacturer Model (Operating System [x64])
    5SBS - Printer Drivers - RICOH MP C3003 (Win11 x64)

.Example
powershell.exe -executionpolicy bypass -file .\Install-BrotherPrinter.ps1 -PrinterFriendlyName "Admin Printer" -PrinterIP "192.168.1.5" -DriverName "Brother MFC-L8690CDW series" -MSI "PrintDriver.msi"
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [String]$RepoFolderName,
    [Parameter(Mandatory = $false)]
    [String]$PrinterIP,
    [Parameter(Mandatory = $false)]
    [String]$MSI,
    [Parameter(Mandatory = $false)]
    [String]$PrinterFriendlyName,
    [Parameter(Mandatory = $false)]
    [Switch]$SetAsDefault,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableDebugLogging
)
# Variables
# Ninja script variable overrides
if ($env:githubRepoFolderName)           {$RepoFolderName = $env:githubRepoFolderName}
if ($env:printerIpAddress)               {$PrinterIP = $env:printerIpAddress}
if ($env:msiFilename)                    {$MSI = $env:msiFilename}
if ($env:printerFriendlyName)            {$PrinterFriendlyName = $env:printerFriendlyName}
if ($env:setAsDefault -eq 'true')        {$SetAsDefault = $true}
if ($env:enableDebugLogging -eq 'true')  {$EnableDebugLogging = $true}

# File paths
$url              = "https://github.com/5sbs/installers/raw/refs/heads/main/Printers/$RepoFolderName/$RepoFolderName.zip" # Source (archive)
$destination      = "C:\5SBS\Printer\Brother\$RepoFolderName"                                                             # Destination folder
$destinationName  = Split-Path $url -Leaf                                                                 # Destination filename
$zipFilePath      = "$destination\$destinationName"                                                       # Archive full path
$zipExtractedPath = "$destination\extracted"                                                              # Archive extracted files path
$logPath          = "C:\5SBS\Logs\$RepoFolderName.log"                                                    # Log full path

# Logging
$logArgs = "/L*v `"$logPath`""

if ($EnableDebugLogging)  {
    Write-Host '[DEBUG] Logging enabled.'
    Write-Host "[DEBUG] Log arguments  : $logArgs"
    Write-Host "[DEBUG] Log file path  : $logPath"
    $logFolder = Split-Path $logPath -Parent
    if (!(Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder | Out-Null}
    }
else {
    $logArgs = ''}

# Installer core args
# Final command will look like: msiexec /i PrintDriver.msi /q /L*v <log file> DRIVERNAME="Brother MFC-L8690CDW series" IPADDRESS=192.168.1.5 PRINTERNAME="Admin Printer" ISDEFAULTPRINTER=1
$installArgs = "/i `"$zipExtractedPath\$MSI.msi`" /q $logArgs"

# Begin
# Download driver install files
Write-Output "[INFO] Downloading print driver for: $RepoFolderName"
if (!(Test-Path $destination)) {
    New-Item -ItemType Directory -Path $destination | Out-Null
}

try {
    Invoke-WebRequest -Uri $url -OutFile ($tempFile = New-TemporaryFile) -Method Get
    Move-Item -LiteralPath $tempFile -Destination $zipFilePath -Force
    Write-Output '[INFO] Download complete'
} catch {
    Write-Output '[ERROR] Download failed! Exiting with error'
    exit 1
}

# Extract archive
Write-Output '[INFO] Extract archive to temp folder'
Expand-Archive $zipFilePath -DestinationPath "$zipExtractedPath" -Force
if (!(Test-Path $zipExtractedPath)) {
    Write-Output '[ERROR] Extract failed! Exiting with error'
    exit 1
}
Write-Output '[INFO] Extract complete'

# Validate Driver Name
Write-Output "[INFO] Looking for Driver Name"
try {
    $driverName = Get-Content -Path "$zipExtractedPath\DriverName.txt"}
catch {
    Write-Output '[ERROR] Could not find Driver Name!'
    exit 1
}
Write-Output "[INFO] Driver Name detected: $driverName"

# Build msiexec args
$installArgs += " DRIVERNAME=`"$driverName`" IPADDRESS=$PrinterIP"
if ($PrinterFriendlyName) {$installArgs += " PRINTERNAME=`"$PrinterFriendlyName`""}
if ($SetAsDefault)        {$installArgs += " ISDEFAULTPRINTER=1"}

# Run msiexec to install driver
Write-Output "[INFO] Running install: msiexec $installArgs"
$process = Start-Process msiexec -ArgumentList $installArgs -PassThru -Wait
$exitCode = $process | Select-Object -ExpandProperty ExitCode
Write-Output "[INFO] msiexec finished running -- exit code $exitCode"

# Delete downloaded files
Write-Output '[INFO] Tidying files'
Remove-Item -Path $destination -Recurse

Write-Output "[INFO] Finished! Exiting with code $exitCode"
exit $exitCode