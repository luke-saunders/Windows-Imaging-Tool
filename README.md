# Windows-Imaging-Tool
Used to image a Windows installation and create an installable Windows ISO
- Hardware independent imaging (use sysprep before imaging)
- Image compression
- Allows for deployment to any size disk (e.g. smaller disks)

### Dependencies
* Windows Assessment and Deployment Kit
  * Deployment Tools
  * Windows Preinstallation Environment Environment (Windows PE)
* Rufus, or similar
* USB drive of sufficient capacity

---
## Create the Bootable USB
1. Check/update variables in Build-WindowsImagingTool.ps1
    - Windows ISO - use the same variant as the Windows installation to be imaged (e.g. WS2012R2)
    - Windows ADK path
    - etc
3. Run Build-WindowsImagingTool.ps1 to create the Imaging Tool ISO
4. Use Rufus and the ISO from #1 to create a bootable USB disk

## Imaging Windows
1. Insert the USB drive into the source hardware to be imaged
2. Power-on and select to boot from the USB drive (UEFI Boot Options)
3. Follow the instructions to select the Windows installation driveletter and destination path
4. The imaging process will take some time.  At completion, a bootable/installable Windows ISO will be generated.
