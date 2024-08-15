<#
.NOTES
Created by:		Russell Hamker
Date:			July 28, 2020
Version:		1.0
Twitter:		@butch7903
GitHub:			https://github.com/butch7903

.SYNOPSIS
	This script will Import the vApp Settings for any VM from a JSON File.

.DESCRIPTION
	Use this script to select a VM that had vApp settings originally 
	applied. This script will then import the VMs vApp configuration 
	from a JSON file and restore it to the VM.

.EXAMPLE
	#Example 1 
	$VCSA = "hamvc01.hamker.local"
	$VMName = "VROPS"
	$JSONFilePath = "/opt/vcsa-mgmt/backup_restore_vm_vapp/export/VROPS_Export-VM-vApp-Configuration.json"
	$Confirm = $false #Do false for full automation tasks
	./import-vm-vapp-configuration.ps1 -VCSA $VCSA -VMName $VMName -JSONFilePath $JSONFilePath -Confirm $false
		
#>

param(
	[Parameter(Mandatory=$true)][String]$VCSA,
	[Parameter(Mandatory=$true)][String]$VMName,
	[Parameter(Mandatory=$true)][String]$JSONFilePath,
	[Parameter(Mandatory=$false)][Boolean]$Confirm
)
If($Confirm.Count -eq 0){$Confirm = $true}

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

##Adding Function needed for copy object information in PowerShell
#Reference: https://code.vmware.com/forums/2530/vsphere-powercli#577076
function Copy-Property ($From, $To, $PropertyName ="*")
{
  foreach ($p in Get-Member -In $From -MemberType Property -Name $propertyName)
  {        trap {
      Add-Member -In $To -MemberType NoteProperty -Name $p.Name -Value $From.$($p.Name) -Force
      continue
    }
    $To.$($P.Name) = $From.$($P.Name)
  }
}

##Written by Russell Hamker
function Import-VM-vApp-Configuration ([string]$JSONFILEPATH, [string]$VNMANE)
{
	If(!$JSONFILEPATH){
		$JSONFILEPATH = Read-Host "Please Provide the VM JSON File Path"
	}
	If(!$VNMANE){
		$VNMANE = Read-Host "Please provide the VM Name you wish to restore vApp settings to"
	}
	Write-Output "Importing VM vAPP settings for $JSONFILEPATH"
	#Convert to VARIABLE
	Write-Host "Importing JSON From $JSONFILEPATH"
	$JSON = Get-Content $JSONFILEPATH | ConvertFrom-Json 
	#Create SPEC and vAppConfig Objects
	$SPEC = New-Object VMware.Vim.VirtualMachineConfigSpec
	$SPEC.VAppConfig = New-Object VMware.Vim.VmConfigSpec
	#Get VM that needs vApp Settings Restored
	$VM = Get-VM -Name $VMNAME
	##Recreate Product Information
	Write-Host "Recreating Production Information"
	$PRODUCTARRAY = @()
	$PRODUCTS = $JSON.Product
	ForEach($PROD in $PRODUCTS)
	{
		$PRODUCTTEMP = $null
		$PRODUCTTEMP = New-Object VMware.Vim.VAppProductSpec
		$PRODUCTTEMP[0].Info = New-Object VMware.Vim.VAppProductInfo
		$PRODUCTTEMP[0].Info.key = $PROD.Key
		$PRODUCTTEMP[0].Info.ClassId = $PROD.ClassId
		$PRODUCTTEMP[0].Info.InstanceId = $PROD.InstanceId
		$PRODUCTTEMP[0].Info.Name = $PROD.Name
		$PRODUCTTEMP[0].Info.Vendor = $PROD.Vendor
		$PRODUCTTEMP[0].Info.Version = $PROD.Version
		$PRODUCTTEMP[0].Info.FullVersion = $PROD.FullVersion
		$PRODUCTTEMP[0].Info.VendorUrl = $PROD.VendorUrl
		$PRODUCTTEMP[0].Info.ProductUrl = $PROD.ProductUrl
		$PRODUCTTEMP[0].Info.AppUrl = $PROD.AppUrl
		$PRODUCTARRAY += $PRODUCTTEMP
	}
	$SPEC.VAppConfig.Product = $PRODUCTARRAY
	##Recreate Property Information
	Write-Host "Recreating Property Information"
	$PROPERTYARRAY = @()
	$PROPERTYS = $JSON.Property
	ForEach($PROP in $PROPERTYS)
	{
		$PROPERTYTEMP = $null
		$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
		$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
		$PROPERTYTEMP[0].Info.key = $PROP.key
		$PROPERTYTEMP[0].Info.ClassId = $PROP.ClassId
		$PROPERTYTEMP[0].Info.InstanceId = $PROP.InstanceId
		$PROPERTYTEMP[0].Info.Id = $PROP.Id
		$PROPERTYTEMP[0].Info.Category = $PROP.Category
		$PROPERTYTEMP[0].Info.Label = $PROP.Label
		$PROPERTYTEMP[0].Info.Type = $PROP.Type
		$PROPERTYTEMP[0].Info.TypeReference = $PROP.TypeReference
		$PROPERTYTEMP[0].Info.UserConfigurable = $PROP.UserConfigurable
		$PROPERTYTEMP[0].Info.DefaultValue = $PROP.DefaultValue
		$PROPERTYTEMP[0].Info.Value = $PROP.Value
		$PROPERTYTEMP[0].Info.Description = $PROP.Description
		$PROPERTYARRAY += $PROPERTYTEMP
	}
	$SPEC.VAppConfig.Property = $PROPERTYARRAY
	##Recreate IP Assignment
	Write-Host "Recreating IP Assignment Information"
	$IPASSIGNMENTLIST = $JSON.IPAssignment
	$IpAssignment = $null
	$IpAssignment = New-Object VMware.Vim.VAppIPAssignmentInfo
	$IpAssignment[0].IpAllocationPolicy = $IPASSIGNMENTLIST.IpAllocationPolicy
	$SupportedIpProtocol = @()
	$IpProtocol = $IPASSIGNMENTLIST.SupportedIpProtocol
	ForEach($Protocol in $IpProtocol)
	{
		$SupportedIpProtocol += $Protocol
	}
	$IpAssignment[0].SupportedIpProtocol = $SupportedIpProtocol
	$IpAssignment[0].IpProtocol = $IPASSIGNMENTLIST.IpProtocol
	$SPEC.VAppConfig.IpAssignment = $IpAssignment
	##Recreate Eula
	Write-Host "Recreating Eula Information"
	$SPEC.VAppConfig.Eula = $JSON.Eula
	##Recreate OvfEnvironmentTransport
	Write-Host "Recreating OvfEnvironmentTransport Information"
	$SPEC.VAppConfig.OvfEnvironmentTransport = $JSON.OvfEnvironmentTransport
	##Recreate InstallBootRequired
	Write-Host "Recreating InstallBootRequired Information"
	$SPEC.VAppConfig.InstallBootRequired = $JSON.InstallBootRequired
	##Recreate InstallBootStopDelay
	Write-Host "Recreating InstallBootStopDelay Information"
	$SPEC.VAppConfig.InstallBootStopDelay = $JSON.InstallBootStopDelay
	##Save SPEC Information back to VM vAPP
	Write-Host "Saving SPEC Information back to VM vAPP $VMNAME"
	$VM.ExtensionData.ReconfigVM_Task($SPEC)
	Write-Host "Completed saving SPEC Information back to VM vAPP $VMNAME"
}

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
Write-Host "Start Time $STARTTIME"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$LOCATION = Get-Location

<#
##Setting CSV File Location 
$CSVFILELOCATION = $LOCATION.path

##Select VCSA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import VCSA File or Create 1
$VCSACSVFILENAME = "VCSAlist.csv"
$VCSACSVFILEGET = Get-Item "$CSVFILELOCATION\$VCSACSVFILENAME" -ErrorAction SilentlyContinue
$VCSACSVFILE = "$CSVFILELOCATION\$VCSACSVFILENAME"
If(!$VCSACSVFILEGET)
{
	Clear-Host
	Write-Host "VCSA List CSV File not found"
	$VCSANAME = @()
	$CREATENEWRECORD = "" | Select-Object VCSA
	$CREATENEWRECORD.VCSA = "Create New Record" 
	$VCSANAME += $CREATENEWRECORD
	$VCSATEMPLIST = "" | Select-Object VCSA
	$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
	$VCSANAME += $VCSATEMPLIST
	$VCSANAME | Export-CSV -NoTypeInformation -PATH $VCSACSVFILE
	$VCSA = $VCSATEMPLIST.VCSA
	Write-Host "VCSA Selected is $VCSA"
}
If($VCSACSVFILEGET)
{
	Clear-Host
	Write-Host "VCSA List CSV File found. Importing file..."
	$VCSALIST = Import-CSV -PATH $VCSACSVFILE
	$VCSASITELIST = $VCSALIST | Where-Object {$_.Site -eq $SITE -or $_.Site -eq "NA"}
	$countCL = 0  
	foreach($oC in $VCSASITELIST)
	{   
		$NAME = $oC.VCSA
		Write-Output "[$countCL] $NAME" 
		$countCL = $countCL+1  
	}
	Write-Host " "  
	$choice = $null
	$choice = Read-Host "On which VCSA do you wish to work with a vApp"
	$CHOICEPICKED = ($VCSASITELIST[$choice]).VCSA
	If($CHOICEPICKED -eq "Create New Record")
	{
		$VCSANAME = $VCSALIST
		Write-Host "Creating New Record Selected..."
		$VCSATEMPLIST = "" | Select-Object VCSA
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
#>

##Check for VCSA Parameter
If(!$VCSA){
	Write-Error "No VCSA Specified"
}
IF($VCSA){
	Write-Host "VCSA Specified in Parameter is $VCSA"
}
	
##Create Secure AES Keys for User and Password Management
$KeyFile = $LOCATION.path+"\"+"AES.key"
If (Test-Path $KeyFile){
	Write-Host "AES File Exists"
	$Key = Get-Content $KeyFile
	Write-Host "Continuing..."
}Else{
	$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
	[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
	$Key | out-file $KeyFile
}

##Create Secure XML Credential File for vCenter/NSX Access
$MgrCreds = $LOCATION.path+"\"+"$VCSA.xml"
If (Test-Path $MgrCreds){
	Write-Host "$VCSA.xml file found"
	Write-Host "Continuing..."
	$ImportObject = Import-Clixml $MgrCreds
	$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
	$MyCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
}Else{
	Write-Host "Credentials File Not Found, Please input Credentials"
	$newPScreds = Get-Credential -message "Enter vCenter Admin Creds here:"
	#$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
	#$rng.GetBytes($Key)
	$exportObject = New-Object psobject -Property @{
		UserName = $newPScreds.UserName
		Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
	}

	$exportObject | Export-Clixml ($VCSA +".xml")
	$MyCredential = $newPScreds
}

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $VCSA + "_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $LOCATION.path+"\log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $LOCATION.path+"\log\"+$LOGFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Provide Credentials
Clear-Host
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
$VISERVER = Connect-VIServer -server $VCSA -Credential $MyCredential -ErrorAction Stop
Write-Host "Connected to vCenter $VISERVER"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Import VM vApp Configuration and Save it to VM
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Beginning Export of VM vApp Configuration"
If(!$VMName){
	$VMName = Read-Host "Please Provide the VM Name of the VM with vApp settings you wish to Modify"
}
If(!$JSONFilePath){
	$JSONFilePath = Read-Host "Please provide the full file path to the JSON Export file"
}
Import-VM-vApp-Configuration $JSONFilePath $VMName
Write-Host "Completed Export of VM $VMName vApp Configuration"
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
Write-Host "Script Completed for $VCSA"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
