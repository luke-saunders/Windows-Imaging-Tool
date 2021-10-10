#############################################################################################
# Windows Imaging Tool - ISO Builder
# Luke Saunders 
#############################################################################################

# Windows ISO
$WindowsIso = "D:\ISOs\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9-WS2012R2.ISO"

# Drivers for the destination hardware (e.g. PERC)
$DriversFolder = "D:\Drivers"

# Scratch folder
$ScratchFolder = "D:\Scratch\WinPE"

# ADK path
$AdkPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"

# CAB files for WinPE
$CabFiles = @("WinPE-WMI.cab","en-us\WinPE-WMI_en-us.cab", "WinPE-NetFX.cab","en-us\WinPE-NetFX_en-us.cab", "WinPE-Scripting.cab","en-us\WinPE-Scripting_en-us.cab", "WinPE-PowerShell.cab","en-us\WinPE-PowerShell_en-us.cab", "WinPE-StorageWMI.cab","en-us\WinPE-StorageWMI_en-us.cab", "WinPE-DismCmdlets.cab","en-us\WinPE-DismCmdlets_en-us.cab")  



#############################################################################################

Write-Host "`n`nINFO: Script started: $($MyInvocation.MyCommand.Name)" -ForegroundColor Green

$BuildFolder    = "$ScratchFolder\Build_Folder"
$BootWimMount   = "$ScratchFolder\BootWim_Mount"
$OutputISO      = "$PSScriptRoot\WindowsImagingTool.iso"
$ToolBoxFolder  = "$BuildFolder\ToolBox"
$WinIsoFolder   = "$ToolBoxFolder\WinISO"

$AdkDevTools    = "$AdkPath\Deployment Tools\amd64"
$AdkWinPE       = "$AdkPath\Windows Preinstallation Environment"
$WinPE_OCs      = "$AdkPath\Windows Preinstallation Environment\amd64\WinPE_OCs"

Write-Host "INFO: Checking dependencies"
foreach ($Item in @($WindowsIso, $DriversFolder, $AdkDevTools, $AdkWinPE)) {
    if (-not(Test-Path $Item)) { 
        throw "ERROR: Dependency not found - $Item"
    }
}

# Create scratch folder.  Throw if the folder already exists.
Write-Host "INFO: Initialising build environment"
if (Test-Path -Path $ScratchFolder) {
    throw "Folder already exists: $ScratchFolder"
} else {
    New-Item -Path $ScratchFolder -ItemType Directory | Out-Null
}
New-Item -Path $BootWimMount -ItemType Directory | Out-Null
New-Item -Path $WinIsoFolder -ItemType Directory | Out-Null 
New-Item -Path "$BuildFolder\sources" -ItemType Directory | Out-Null 

# Copy WinPE files
Write-Host "INFO: Copying project files ... " -NoNewline
Copy-Item -Path "$AdkWinPE\amd64\media\*" -Destination $BuildFolder -Recurse
Copy-Item -Path "$AdkWinPE\amd64\en-us\winpe.wim" -Destination "$BuildFolder\sources\boot.wim" -Force
Copy-Item -Path "$AdkDevTools\DISM" -Destination $ToolBoxFolder -Recurse
Copy-Item -Path "$AdkDevTools\Oscdimg" -Destination $ToolBoxFolder -Recurse
Write-Host "DONE"

# Mount the boot wim
Write-Host "INFO: Mounting boot.wim"
Mount-WindowsImage -Checkintegrity -ImagePath "$BuildFolder\sources\boot.wim" -Index 1 -Path $BootWimMount | Out-Null

# Add PowerShell etc
foreach ($CabFile in $CabFiles) {
    $PackagePath = "$WinPE_OCs\$CabFile"
    if (Test-Path -Path $PackagePath) {
        Write-Host "INFO: Adding package - $CabFile"
        Add-WindowsPackage -Path $BootWimMount -PackagePath $PackagePath -IgnoreCheck | Out-Null
    } else {
        Write-Host "ERROR: Can't find package: $PackagePath" -ForegroundColor Red
    }
}

# Add Drivers to the wim
if (Test-Path -Path $DriversFolder) {
    Write-Host "INFO: Adding drivers ... " -NoNewline
    Add-WindowsDriver -Path $BootWimMount -Driver $DriversFolder -Recurse | Out-Null
    Write-Host "DONE"
    # Alternate option - add driver files to $WinPEDriver$
} else {
    Write-Host "Add Drivers: Can't find item: $DriversFolder" -ForegroundColor Red
}

# Append to startnet.cmd
Write-Host "INFO: Updating startnet.cmd"
$StartNetCmd = @'
powershell -NoLogo -ExecutionPolicy ByPass -File StartNet.ps1
'@
Add-Content -Path ($BootWimMount + '\Windows\System32\startnet.cmd') -Encoding UTF8 -Value $StartNetCmd

# Create startnet.ps1
Write-Host "INFO: Adding startnet.ps1"
$StartNetPs1 = @'
# Find and execute script: Export-WindowsISO.ps1
Get-Volume | ForEach-Object { if (Test-Path -Path ($_.DriveLetter + ":\ToolBox\Export-WindowsISO.ps1")) { $DriveLetter = $_.DriveLetter + ':' }}
& $DriveLetter\ToolBox\Export-WindowsISO.ps1
'@
Add-Content -Path ($BootWimMount + '\Windows\System32\startnet.ps1') -Encoding UTF8 -Value $StartNetPs1

# Dismount and save the boot wim
Write-Host "INFO: Dismounting boot.wim"
Dismount-WindowsImage -Path $BootWimMount -save | Out-Null

# Mount Windows ISO and copy contents to the WinISO folder
Write-Host "INFO: Mounting the Windows ISO"
$MountPoint = Mount-DiskImage -ImagePath $WindowsIso -PassThru
$MountPointVolume = ($MountPoint | Get-Volume).DriveLetter
Write-Host "INFO: Copying contents from the Windows ISO"
Copy-Item -Path ($MountPointVolume + ":\*") -Destination $WinIsoFolder -Recurse
Write-Host "INFO: Dismounting the Windows ISO"
Dismount-DiskImage -ImagePath $WindowsIso | Out-Null

# Script for capturing the Windows installation to an installable ISO
Copy-Item -Path ".\Export-WindowsISO.ps1" -Destination "$ToolBoxFolder\Export-WindowsISO.ps1"

### ##### CREATE ISO IMAGE #####
Write-Host "INFO: Creating the Windows Imaging Tool ISO file"
& "$AdkDevTools\Oscdimg\Oscdimg.exe" -b"$AdkDevTools\Oscdimg\efisys.bin" -pEF -u1 -udfver102 $BuildFolder $OutputISO
Write-Host "INFO: File created: $OutputISO" -ForegroundColor Green

Write-Host "INFO: Removing the scratch folder"
Remove-Item -Path $ScratchFolder -Recurse -Force

Write-Host "`n`nINFO: Script complete: $($MyInvocation.MyCommand.Name)"