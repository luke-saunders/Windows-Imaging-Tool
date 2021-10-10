#############################################################################################
# Export Windows to an installable ISO
# Luke Saunders 
#############################################################################################

Write-Host "`n`nINFO: Script started: $($MyInvocation.MyCommand.Name)" -ForegroundColor Green

do {
    Write-Host "`n`n"

    # Find Windows driveletter.  NOTE: Doesn't check for multiple results.
    Get-Volume | ForEach-Object { if (Test-Path -Path ($_.DriveLetter + ":\Windows")) { $WinDriveLetter = $_.DriveLetter }}
    if ($WinDriveLetter -eq '') { throw 'ERROR: Windows folder not found.' }

    # Find the USB drive. NOTE: Doesn't check for multiple results.
    Get-Volume | ForEach-Object { if (Test-Path -Path ($_.DriveLetter + ":\ToolBox")) { $UsbDrive = $_.DriveLetter + ':' }}
    if ($UsbDrive -eq '') { throw 'ERROR: ToolBox folder not found.' }

    # User to select Windows drive letter
    Get-Volume | Where-Object { Test-Path -path ($_.DriveLetter + ':\Windows') } | Out-Host
    $PromptDriveLetter = Read-Host -Prompt "Select the DriveLetter of Windows [$WinDriveLetter]"
    if ($PromptDriveLetter -ne '') { 
        $WindowsDrive = $PromptDriveLetter + ':\'
    } else {
        $WindowsDrive = $WinDriveLetter + ':\'
    }

    # User to select the destination drive.  Drive will also be used for scratch folders.
    Write-Host "`n"
    Get-Volume | Out-Host
    $DestFolder = Read-Host -Prompt "Enter the destination path"
    $ScratchFolder  = $DestFolder + '\scratch'
    if (Test-Path $ScratchFolder) {
        throw "ERROR: Folder already exists: $DestFolder"
    }

    # Define the ISO filename
    $IsoFilename = Read-Host -Prompt "Enter the ISO filename [WindowsImage.iso]"
    if ($IsoFilename -ne '') { 
        $OutputIso = Join-Path -Path $DestFolder -ChildPath $IsoFilename
    } else {
        $OutputIso = Join-Path -Path $DestFolder -ChildPath 'WindowsImage.iso'
    }

    Write-Host ("`n`n`n------ PLEASE CONFIRM ------") -ForegroundColor Yellow
    Write-Host ("Windows Drive:    $WindowsDrive")
    Write-Host ("Destination ISO:  $OutputIso `n")

    $confirm = Read-Host -Prompt "Continue [y\n]"

} while ($confirm.tolower() -ne 'y') 

$ToolBoxFolder  = $UsbDrive + '\ToolBox' 
$BuildFolder    = $ScratchFolder + '\Build_Folder'
$ScratchWim     = $ScratchFolder + '\Windows_Image'

# Create a build folder, copy WinISO contents, and the custom install.wim
Write-Host "INFO: Initialising folders"
New-Item -Path $ScratchWim -ItemType Directory | Out-Null
New-Item -Path $BuildFolder -ItemType Directory | Out-Null

Write-Host "INFO: Copying Windows ISO content ... " -NoNewLine
Copy-Item -Path ("$ToolBoxFolder\WinISO\*") -Destination $BuildFolder -Recurse
Write-Host "DONE"

# Capture the Windows image to install.wim, in place of the stock file
Write-Host "INFO: Capture image of Windows installation ... " -NoNewLine
$InstallWim = $BuildFolder + '\Sources\install.wim'
Remove-Item -Path $InstallWim -Force
New-WindowsImage -ImagePath $InstallWim -CapturePath $WindowsDrive -Name 'WindowsImage' -ScratchDirectory $ScratchWim  -CompressionType Max -CheckIntegrity -Verify -Setbootable
Write-Host "DONE"

& "$ToolBoxFolder\Oscdimg\Oscdimg.exe" -m -o -b"$ToolBoxFolder\Oscdimg\Efisys.bin" -pEF -u2 -udfver102 $BuildFolder $OutputIso
Write-Host "`nINFO: ISO File: $OutputIso" -ForegroundColor Green

Write-Host "INFO: Removing the scratch folder"
Remove-Item -Path $ScratchFolder -Recurse -Force

Write-Host "`n`nINFO: Script complete: $($MyInvocation.MyCommand.Name)"