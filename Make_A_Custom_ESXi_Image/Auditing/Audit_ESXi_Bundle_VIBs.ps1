<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			April 21,2021
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will export a list of VIBs used in an ESXi offline Bundle.


	.DESCRIPTION
		Use this script to audit the vibs in an ESXi offline Bundle.	

	.NOTES
	Based on 
	https://blogs.vmware.com/vsphere/2017/05/apply-latest-vmware-esxi-security-patches-oem-custom-images-visualize-differences.html
#>

##Check if Modules are installed, if so load them, else install them
if (Get-InstalledModule -Name VMware.PowerCLI -MinimumVersion 11.4) {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module VMware PowerCLI required minimum version was found previously installed"
	Write-Host "Importing PowerShell Module VMware PowerCLI"
	Import-Module -Name VMware.PowerCLI
	Write-Host "Importing PowerShell Module VMware PowerCLI Completed"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#CLEAR
} else {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module VMware PowerCLI does not exist"
	Write-Host "Setting Micrsoft PowerShell Gallery as a Trusted Repository"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Write-Host "Verifying that NuGet is at minimum version 2.8.5.201 to proceed with update"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
	Write-Host "Uninstalling any older versions of the VMware PowerCLI Module"
	Get-Module VMware.PowerCLI | Uninstall-Module -Force
	Write-Host "Installing Newest version of VMware PowerCLI PowerShell Module"
	Install-Module -Name VMware.PowerCLI -Scope AllUsers
	Write-Host "Creating a Desktop shortcut to the VMware PowerCLI Module"
	$AppLocation = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
	$Arguments = '-noe -c "Import-Module VMware.PowerCLI"'
	$WshShell = New-Object -ComObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut("$Home\Desktop\VMware PowerCLI.lnk")
	$Shortcut.TargetPath = $AppLocation
	$Shortcut.Arguments = $Arguments
	$ShortCut.Hotkey = "CTRL+SHIFT+V"
	$Shortcut.IconLocation = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe,1"
	$Shortcut.Description ="Launch VMware PowerCLI"
	$Shortcut.WorkingDirectory ="C:\"
	$Shortcut.Save()
	Write-Host "Shortcut Created"
	Write-Host "You may use the CTRL+SHIFT+V method to open VMware PowerCLI"
	Write-Host "Importing PowerShell Module VMware PowerCLI"
	Import-Module -Name VMware.PowerCLI
	Write-Host "PowerShell Module VMware PowerCLI Loaded"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#Clear
}

##Get Current Path
$pwd = pwd

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

#Type in User input info
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
$ZIP = read-host "Please provide the full path to the Manufacturer Offline Bundle (.Zip File from Dell, HPE, Cisco, etc.)
Example: 
E:\scripts\rhamker\Audit_ESXi_Bundle_VIBs\ESXi\ESXi-7.0-17551050-standard.zip
"
$ZIPFILE = Split-Path $ZIP -leaf
$ZIPFILE
#https://vibsdepot.hpe.com/hpe/oct2020/local-metadata-hpe-esxi-drv-bundles-670.U3.10.6.0.zip
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $ZIPFILE + "_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\Log\"+$LOGFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Add Manufacturer Offline bundle
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Adding Software Depot/Offline Bundle: 
$ZIP"
$MANUDEPOT = Add-EsxSoftwareDepot $ZIP
$ESXIMAGEPROFILE = Get-EsxImageProfile | select * #Gets details of what is in the $ZIP file
Write-Host "Listing Manufacturer's ESXi Image Profile:"
$ESXIMAGEPROFILE
$ORIGINALVIBLIST = Get-EsxSoftwarePackage | Sort Name
Write-Host "VIB List for Manufacturer ESX Image Profile will include:"
Write-Output $ORIGINALVIBLIST | ft
Write-Host "VIB Count for Manufacturer ESX Image Profile:"
Write-Output $ORIGINALVIBLIST.count
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#List all Bundles
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Listing all Bundles added"
Get-EsxSoftwareDepot
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Get Newest VIBs
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Getting a list of the newest VIBs"
$VIBLIST = Get-EsxSoftwarePackage -Newest | sort Name,'Creation Date'
Write-Host "VIB List for New ESX Image Profile will include:"
Write-Output $VIBLIST | ft
Write-Host "VIB Count for New ESX Image Profile:"
Write-Output $VIBLIST.count
$ESXIMAGEVERSION =  ($VIBLIST  | Where {$_.Name -like "esx-base"}).Version
Write-Host "ESXi Version is $ESXIMAGEVERSION"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Create ESXImageProfile
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating new ESX Image Profile"
If($ESXIMAGEPROFILE.Description)
{
	$ESXIMAGEPROFILEDescription	= $ESXIMAGEPROFILE.Description
}Else{
	$ESXIMAGEPROFILEDescription	= "$ESXIMAGEPROFILE.vendor Image Based On $ESXIMAGEPROFILE.Name"
}
<#
If($VIBLISTALTERED)
{
	Write-Host "Creating New ESX Image Profile Based on the Altered VIB List (Unused VIBs were removed)"
	$EDITION = Get-Date -format "MMMddyyyy"
	$NewProfileName = ($ESXIMAGEPROFILE.Name + "_custom_" + $EDITION)
	$NEWESXIMAGEPROFILE = New-EsxImageProfile -NewProfile $NewProfileName -SoftwarePackage $VIBLISTALTERED `
    -Vendor $ESXIMAGEPROFILE.Vendor  -AcceptanceLevel $ESXIMAGEPROFILE.AcceptanceLevel -Description $ESXIMAGEPROFILEDescription `
    -ErrorAction Stop -ErrorVariable CreationError
	
	$ESXIMAGEVERSION = ($VIBLISTALTERED | Where {$_.Name -like "esx-base"}).Version
}Else{
	Write-Host "Creating New ESX Image Profile Based on the Unique/Newest VIB List (No unused VIBs were removed)"
	$EDITION = Get-Date -format "MMMddyyyy"
	$NewProfileName = ($ESXIMAGEPROFILE.Name + "_custom_" + $EDITION)
	$NEWESXIMAGEPROFILE = New-EsxImageProfile -NewProfile $NewProfileName -SoftwarePackage $VIBLIST `
    -Vendor $ESXIMAGEPROFILE.Vendor  -AcceptanceLevel $ESXIMAGEPROFILE.AcceptanceLevel -Description $ESXIMAGEPROFILEDescription `
    -ErrorAction Stop -ErrorVariable CreationError
	
	$ESXIMAGEVERSION =  ($VIBLIST  | Where {$_.Name -like "esx-base"}).Version
}
Write-Host "Completed Creating New ESX Image Profile"
Write-Output ($NEWESXIMAGEPROFILE | Select *)
#>
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

<#
##Compare ESX Image Profiles
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Comparing Original Manufacturer's ESX Image Profile with Updated ESX Image Profile $NewProfileName"
$PROFILECOMPARE = Compare-EsxImageProfile -ReferenceProfile $ESXIMAGEPROFILE.Name -ComparisonProfile $NEWESXIMAGEPROFILE.Name | Select *
Write-Host "Completed Comparing Original Manufacturer's ESX Image Profile with Updated ESX Image Profile $NewProfileName"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
#>

##Specify Export File Info
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
#Create Export Folder
$EXPORTFOLDERNAME = $ESXIMAGEVERSION
$ExportFolder = $pwd.path+"\Export\"#+$EXPORTFOLDERNAME+"_"+$LOGDATE
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}

#Specify Log File
$ORIGCSV = $ExportFolder+"\"+(($ESXIMAGEPROFILE.Name)+".csv")
<#
$EXPORTCSV = $ExportFolder+"\"+($NewProfileName+"_"+$ESXIMAGEVERSION+".csv")
$EXPORTZIP = $ExportFolder+"\"+($NewProfileName+"_"+$ESXIMAGEVERSION+".zip")
$EXPORTISO = $ExportFolder+"\"+($NewProfileName+"_"+$ESXIMAGEVERSION+".iso")
$COMPARETXT = $ExportFolder+"\"+($ESXIMAGEPROFILE.Name)+"_Comparison_Report.txt"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
#>

#Export Image to ZIP/ISO
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting Data Starting"
Write-Host "Exporting Original VIB list from Manufacturer..." -ForegroundColor Green
$ORIGINALVIBLIST | Export-CSV -Path $ORIGCSV -NoTypeInformation
<#
Write-Host "Exporting New Custom Image to Files"
Write-Host "Creating ZIP bundle..." -ForegroundColor Green
Export-EsxImageProfile -ImageProfile $NEWESXIMAGEPROFILE -ExportToBundle -FilePath $EXPORTZIP -Force
Write-Host "Creating ISO image..." -ForegroundColor Green
Export-EsxImageProfile -ImageProfile $NEWESXIMAGEPROFILE -ExportToIso -FilePath $EXPORTISO -Force
If($VIBLISTALTERED)
{
	Write-Host "Exporting VIB List to CSV..." -ForegroundColor Green
	$VIBLISTALTERED | Export-CSV -Path $EXPORTCSV -NoTypeInformation
}Else{
	Write-Host "Exporting VIB List to CSV..." -ForegroundColor Green
	$VIBLIST | Export-CSV -Path $EXPORTCSV -NoTypeInformation
}
Write-Host "Creating ESX Image Profile Comparison Text Report..." -ForegroundColor Green
$REPORT = "ESX Image Profile Comparison Report
$EXPORTDATE

Original Depot Acceptance Level - $($ESXIMAGEPROFILE.Name) 
$($PROFILECOMPARE.RefAcceptanceLevel)

New Depot Acceptance Level - $($NewProfileName + "_" + $ESXIMAGEVERSION)
$($PROFILECOMPARE.CompAcceptanceLevel)

VIBs Only in Original Depot - $($ESXIMAGEPROFILE.Name) 
$($PROFILECOMPARE.OnlyinRef | Sort | Format-Table | Out-String)

VIBs Only in New Depot - $($NewProfileName + "_" + $ESXIMAGEVERSION) 
$($PROFILECOMPARE.OnlyinComp | Sort | Format-Table | Out-String)

VIBs Upgraded from Original Depot
$($PROFILECOMPARE.UpgradeFromRef | Sort | Format-Table | Out-String)"
$REPORT | Out-File -FilePath $COMPARETXT -NoClobber
#>
Write-Host "Completed exporting New Custom Image to Files"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Document Script Total Run time
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$STARTTIMESW.STOP()
Write-Host "Total Script Time:"$STARTTIMESW.Elapsed.TotalMinutes"Minutes"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Stopping Logging
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "All Processes Completed"
Write-Host "Stopping Transcript"
Stop-Transcript
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Script Completed
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Completed for $NewProfileName"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
