<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			April 23,2020
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will audit the all VMHosts in a VCSA against an exported CSV
		List of VIBs produced by the Audit_ESXi_Bundle_VIBs.ps1

	.DESCRIPTION
		Use this script to audit all the hosts in a VCSA 	
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

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$pwd = pwd

##Setting CSV File Location 
$CSVFILELOCATION = $pwd.path

##VIB Ignore List
#This is a list of VIB Names you want to ignore due to them not being built into the ESXi Image
$IGNORELIST = "vmware-fdm"

##Select VCSA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import VCSA File or Create 1
$VCSACSVFILENAME = "VCSAlist.csv"
$VCSACSVFILEGET = Get-Item "$CSVFILELOCATION\$VCSACSVFILENAME" -ErrorAction SilentlyContinue
$VCSACSVFILE = "$CSVFILELOCATION\$VCSACSVFILENAME"
If(!$VCSACSVFILEGET)
{
	CLS
	Write-Host "VCSA List CSV File not found"
	$VCSANAME = @()
	$CREATENEWRECORD = "" | Select VCSA
	$CREATENEWRECORD.VCSA = "Create New Record" 
	$VCSANAME += $CREATENEWRECORD
	$VCSATEMPLIST = "" | Select VCSA
	$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
	$VCSANAME += $VCSATEMPLIST
	$VCSANAME | Export-CSV -NoTypeInformation -PATH $VCSACSVFILE
	$VCSA = $VCSATEMPLIST.VCSA
	Write-Host "VCSA Selected is $VCSA"
}
If($VCSACSVFILEGET)
{
	CLS
	Write-Host "VCSA List CSV File found. Importing file..."
	$VCSALIST = Import-CSV -PATH $VCSACSVFILE
	$VCSASITELIST = $VCSALIST | Where {$_.Site -eq $SITE -or $_.Site -eq "NA"}
	$countCL = 0  
	foreach($oC in $VCSASITELIST)
	{   
		$NAME = $oC.VCSA
		Write-Output "[$countCL] $NAME" 
		$countCL = $countCL+1  
	}
	Write-Host " "  
	$choice = $null
	$choice = Read-Host "On which VCSA do you wish to work with"
	$CHOICEPICKED = ($VCSASITELIST[$choice]).VCSA
	If($CHOICEPICKED -eq "Create New Record")
	{
		$VCSANAME = $VCSALIST
		Write-Host "Creating New Record Selected..."
		$VCSATEMPLIST = "" | Select VCSA
		$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
		$VCSANAME += $VCSATEMPLIST
		$VCSANAME | Export-CSV -NoTypeInformation -PATH $VCSACSVFILE -Confirm:$false
		$VCSA = $VCSATEMPLIST.VCSA
		Write-Host "VCSA Selected is $VCSA"
	}Else{
		$VCSA = $CHOICEPICKED
		Write-Host "VCSA Selected is $VCSA"
	}
}
Write-Host "VCSA Selected is $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"


##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $VCSA + "_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\Log\"+$LOGFILENAME

#Get Export CSV
$ExportFolder = $pwd.path+"\Export"
$NEWESTCSVFILE = Get-ChildItem -Path $ExportFolder | Where {$_.Extension -eq ".csv"} | sort LastWriteTime | select -last 1
$REFVIBS = Import-Csv $NEWESTCSVFILE.FullName

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Provide Credentials
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
If(!$MyCredential)
{
	Write-Host "Please Provide VCSA Administrator based Credentials for VCSA $VCSA"
	$MyCredential = Get-Credential -Message "Please Provide VCSA Creds"
	Write-Host "Credential UserName provided is:"$MyCredential.UserName
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Disconnect from any open vCenter Sessions,
#This can cause problems if there are any
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from any Open vCenter Sessions"
TRY
{Disconnect-VIServer * -Confirm:$false}
CATCH
{Write-Host "No Open vCenter Sessions found"}
Write-Host "Disconnecting from any Open NSX Manager Sessions"
if($DefaultNSXConnection.Server)
{
	Disconnect-NSXServer * -Confirm:$false
}ELSE{
	Write-Host "No Open NSX Server Sessions found"
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Connect to vCenter Server
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Connecting to vCenter $VCSA"
$VCSA = Connect-VIServer -server $VCSA -Credential $MyCredential
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Specify Export File Info
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating Export Folder and File Attributes"
$EXPORTFILENAME = "VMHost_Compare_" + $VCSA + "_Ref_" + $NEWESTCSVFILE.BaseName + "_Compare_" + $VCSA + "_" + $LOGDATE + ".csv"
#Create Export Folder
$ExportFolder = $pwd.path+"\Export_Bundle_to_Host_Audit"
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}
#Specify Log File
$EXPORTFILE = $ExportFolder + "\" + $EXPORTFILENAME
Write-Host "Completed creating Export Folder and File Attributes"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get VMHost List
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Getting VMHost List"
$VMHOSTLIST = Get-VMHost | where {$_.ConnectionState -eq "Connected" -or $_.ConnectionState -eq "Maintenance"} | Sort Name
Write-Host "Completed getting VMHost List"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Checking Each Host in Host List for VIB Differences
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Beginning Comparison for Each VMHost"
$EXPORTARRAY = @()
ForEach($CHKVMHOST in $VMHOSTLIST)
{
	##Get VIB List
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Getting VIBs List from Comparison VMHost $CHKVMHOST" -ForeGroundColor Green
	#ESXCLI
	$esxcli = Get-EsxCli -VMHost $CHKVMHOST -V2
	$CHKVIBs = $esxcli.software.vib.get.Invoke() | Select Name, ID, Description, Version, CreationDate | Sort Name
	Write-Host "Completed getting VIBs List from VMHost $CHKVMHOST"

	##Comparing VIB Lists
	Write-Host "Comparing VIBS Lists"
	$TEMPARRAY = @()
	ForEach($VIB in $CHKVIBS)
	{
		#If Name Match Check to make sure Version Matches, if not add to list
		$MATCHEDVIB = $REFVIBS | where {$_.Name -eq $VIB.Name}
		If($MATCHEDVIB)
		{
			#VIB name match found, checking Version
			If($VIB.Version -ne $MATCHEDVIB.Version)
			{
				Write-Host "VIB Versions do not Match!"
				Write-Host "REFVIB Version:"
				Write-Host $MATCHEDVIB.Name
				Write-Host $MATCHEDVIB.Version
				Write-Host "VMHost Version:"
				Write-Host $VIB.Name
				Write-Host $VIB.Version
				$TARRAY = ""| Select VMHost,Reason,Name,ID,Description,Version,CreationDate
				$TARRAY.VMHost = $CHKVMHOST.Name
				$TARRAY.Reason = "Version Mismatch"
				$TARRAY.Name = $VIB.Name
				$TARRAY.ID = $VIB.ID
				$TARRAY.Description = $VIB.Description
				$TARRAY.Version = $VIB.Version
				$TARRAY.CreationDate = $VIB.CreationDate
				$TEMPARRAY += $TARRAY
			}
		}
		#If Name does not match add to list
		IF(!$MATCHEDVIB)
		{
				$TARRAY = ""| Select VMHost,Reason,Name,ID,Description,Version,CreationDate
				$TARRAY.VMHost = $CHKVMHOST.Name
				$TARRAY.Reason = "Name Not Found"
				$TARRAY.Name = $VIB.Name
				$TARRAY.ID = $VIB.ID
				$TARRAY.Description = $VIB.Description
				$TARRAY.Version = $VIB.Version
				$TARRAY.CreationDate = $VIB.CreationDate
				$TEMPARRAY += $TARRAY
		}
	}
	$EXPORTARRAY += $TEMPARRAY
	Write-Host "Completed VIB comparison for VMHost $CHKVMHOST" -ForeGroundColor Yellow
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
}

##Export Data to CSV
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting Data to CSV"
$EXPORTARRAY | Where {$_.Name -ne $IGNORELIST} | Sort VMHost | Export-CSV -PATH $EXPORTFILE -NoTypeInformation
Write-Host "Exporting Data to CSV Completed"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Document Script Total Run time
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$STARTTIMESW.STOP()
Write-Host "Total Script Time:"$STARTTIMESW.Elapsed.TotalMinutes"Minutes"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Disconnect from vCenter
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from vCenter"
disconnect-viserver $VCSA -confirm:$false
IF ($NSXSERVER)
{
Write-Host "Disconnecting from NSX Manager"
Disconnect-NSXServer -NSXServer $NSXSERVER -Confirm:$false
}
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
Write-Host "Script Completed for $VCENTER"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
