# Variables
# File paths
$url              = 'https://github.com/5sbs/installers/raw/refs/heads/main/McAfeeRemoval/MCPRTool.zip' # Source (archive)
$destination      = 'C:\5SBS\McAfeeConsumerRemoval'                                                     # Destination folder
$destinationName  = 'MCPR.zip'                                                                          # Destination filename
$zipFilePath      = "$destination\$destinationName"                                                     # Archive full path
$zipExtractedPath = "$destination\extracted"                                                            # Archive extracted files path
# Registry paths
$uninstallRegPath = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\McAfee.wps' # McAfee Consumer Protection uninstall key (tool does not remove automatically)

# Download MCPR Tool
Write-Output '[INFO] Downloading McAfee Consumer Product Removal Tool (MCPR)'
if (!(Test-Path $destination)) {
    New-Item -ItemType Directory -Path $destination}
Invoke-WebRequest -Uri $url -OutFile $zipFilePath -Method Get
if (!(Test-Path $zipFilePath)) {
    Write-Output '[ERROR] Download failed! Exiting with error'
    exit 1
}
Write-Output '[INFO] Download complete'

# Extract archive
Write-Output '[INFO] Extract archive to temp folder'
Expand-Archive $zipFilePath -DestinationPath "$zipExtractedPath" -Force
if (!(Test-Path $zipExtractedPath)) {
    Write-Output '[ERROR] Extract failed! Exiting with error'
    exit 1
}

# Run MCPR
Write-Output '[INFO] Running MCPR Tool'
$process = Start-Process "$zipExtractedPath\mccleanup.exe" -ArgumentList "-p StopServices,MFSY,PEF,MXD,CSP,Sustainability,MOCP,MFP,APPSTATS,Auth,EMproxy,FWdiver,HW,MAS,MAT,MBK,MCPR,McProxy,McSvcHost,VUL,MHN,MNA,MOBK,MPFP,MPFPCU,MPS,SHRED,MPSCU,MQC,MQCCU,MSAD,MSHR,MSK,MSKCU,MWL,NMC,RedirSvc,VS,REMEDIATION,MSC,YAP,TRUEKEY,LAM,PCB,Symlink,SafeConnect,MGS,WMIRemover,RESIDUEFWDRIVER,Redir,MSHR,WPS,MSSPlus -v -s" -PassThru -Wait
$exitCode = $process | Select-Object -ExpandProperty ExitCode
write-output "[INFO] MCPR finished running -- exit code $exitCode"

if (Test-Path $uninstallRegPath) {
    Write-Output '[INFO] Uninstall key found in Registry (tool did not remove). Manually removing'
    Remove-Item -Path $uninstallRegPath
}
Write-Output '[INFO] Tidying files'
Remove-Item -Path $destination -Recurse

Write-Output "[INFO] Finished! Exiting with code $exitCode"
exit $exitCode
