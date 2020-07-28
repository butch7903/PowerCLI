<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			July 28, 2020
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will recreate the vApp Settings for vROPs.

	.DESCRIPTION
		Use this script to select a VM that had the vROPs vApp settings 
		originally applied. This script will then manipulate the VMs
		configuration to be set as a vApp.
	.NOTES
		This script requires a VMware PowerCLI minimum version 11.4 or greater. 

	.TROUBLESHOOTING
		
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

##Adding Function needed for manipulating VM Configuration
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

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$pwd = pwd

##Setting CSV File Location 
$CSVFILELOCATION = $pwd.path

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
	$choice = Read-Host "On which VCSA do you wish to work with a vApp"
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
$VISERVER = Connect-VIServer -server $VCSA -Credential $MyCredential
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Create Spec and Export VM Specs
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting SPEC from VM $VMNAME"
$SPEC = New-Object VMware.Vim.VirtualMachineConfigSpec
#Get VM that needs vApp Settings Restored
$VMNAME = Read-Host "Please provide th vApp Appliance's VM name"
$VM = Get-VM -Name $VMNAME
# Copies all properties of the VM to the spec
#Copy-Property -From $VM.ExtensionData.Config -To $SPEC
Write-Host "Completed Exporting SPEC from VM $VMNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Reference
#https://communities.vmware.com/thread/471448
##Create vApp Object
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating vApp Object"
$SPEC.VAppConfig = New-Object VMware.Vim.VmConfigSpec #VMware.Vim.VmConfigInfo
Write-Host "Completed Creating vApp Object"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

Write-Host "Setting vROPs Product Information"
$PRODUCTARRAY = @()
<#
$SPEC.VAppConfig.Product = New-Object VMware.Vim.VAppProductSpec #[] (1)
$SPEC.VAppConfig.Product[0].Info = New-Object VMware.Vim.VAppProductInfo
$SPEC.VAppConfig.Product[0].Info.ClassId = ""
$SPEC.VAppConfig.Product[0].Info.InstanceId = ""
$SPEC.VAppConfig.Product[0].Info.Name = "vRealize Operations Manager Appliance"
$SPEC.VAppConfig.Product[0].Info.Vendor = "VMware Inc."
$SPEC.VAppConfig.Product[0].Info.Version = "7.0.0.10098133"
$SPEC.VAppConfig.Product[0].Info.FullVersion = "7.0.0.10098133 Build 10098135"
$SPEC.VAppConfig.Product[0].Info.VendorUrl = "http://www.vmware.com"
$SPEC.VAppConfig.Product[0].Info.ProductUrl = ""
$SPEC.VAppConfig.Product[0].Info.AppUrl = @'
https://${vami.ip0.vRealize_Operations_Manager_Appliance}/
'@
#>

$n = 0
$PRODUCTTEMP = $null
$PRODUCTTEMP = New-Object VMware.Vim.VAppProductSpec
$PRODUCTTEMP[0].Info = New-Object VMware.Vim.VAppProductInfo
$PRODUCTTEMP[0].Info.key = $n
$PRODUCTTEMP[0].Info.ClassId = ""
$PRODUCTTEMP[0].Info.InstanceId = ""
$PRODUCTTEMP[0].Info.Name = "vRealize Operations Manager Appliance"
$PRODUCTTEMP[0].Info.Vendor = "VMware Inc."
$PRODUCTTEMP[0].Info.Version = "7.0.0.10098133"
$PRODUCTTEMP[0].Info.FullVersion = "7.0.0.10098133 Build 10098135"
$PRODUCTTEMP[0].Info.VendorUrl = "http://www.vmware.com"
$PRODUCTTEMP[0].Info.ProductUrl = ""
$PRODUCTTEMP[0].Info.AppUrl = @'
https://${vami.ip0.vRealize_Operations_Manager_Appliance}/
'@
$PRODUCTARRAY += $PRODUCTTEMP
$n = $n + 1

$PRODUCTTEMP = $null
$PRODUCTTEMP = New-Object VMware.Vim.VAppProductSpec #VMware.Vim.VAppProductInfo
$PRODUCTTEMP[0].Info = New-Object VMware.Vim.VAppProductInfo
$PRODUCTTEMP[0].Info.key = $n
$PRODUCTTEMP[0].Info.ClassId = "vami"
$PRODUCTTEMP[0].Info.InstanceId = "vRealize_Operations_Manager_Appliance"
$PRODUCTTEMP[0].Info.Name = ""
$PRODUCTTEMP[0].Info.Vendor = ""
$PRODUCTTEMP[0].Info.Version = ""
$PRODUCTTEMP[0].Info.FullVersion = ""
$PRODUCTTEMP[0].Info.VendorUrl = ""
$PRODUCTTEMP[0].Info.ProductUrl = ""
$PRODUCTTEMP[0].Info.AppUrl = ""
$PRODUCTARRAY += $PRODUCTTEMP
$n = $n + 1

$PRODUCTTEMP = $null
$PRODUCTTEMP = New-Object VMware.Vim.VAppProductSpec #VMware.Vim.VAppProductInfo
$PRODUCTTEMP[0].Info = New-Object VMware.Vim.VAppProductInfo
$PRODUCTTEMP[0].Info.key = $n
$PRODUCTTEMP[0].Info.ClassId = "vm"
$PRODUCTTEMP[0].Info.InstanceId = ""
$PRODUCTTEMP[0].Info.Name = ""
$PRODUCTTEMP[0].Info.Vendor = ""
$PRODUCTTEMP[0].Info.Version = ""
$PRODUCTTEMP[0].Info.FullVersion = ""
$PRODUCTTEMP[0].Info.VendorUrl = ""
$PRODUCTTEMP[0].Info.ProductUrl = ""
$PRODUCTTEMP[0].Info.AppUrl = ""
$PRODUCTARRAY += $PRODUCTTEMP

$SPEC.VAppConfig.Product = $PRODUCTARRAY


Write-Host "Setting vROPs Property Information"
$PROPERTYARRAY = @()
$n = 0

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = "vami"
$PROPERTYTEMP[0].Info.InstanceId = "vRealize_Operations_Manager_Appliance"
$PROPERTYTEMP[0].Info.Id = "gateway"
$PROPERTYTEMP[0].Info.Category = "Networking Properties"
$PROPERTYTEMP[0].Info.Label = "Default Gateway"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $True
$PROPERTYTEMP[0].Info.DefaultValue = ""
$PROPERTYTEMP[0].Info.Value = Read-Host "Please enter gateway IP"
$PROPERTYTEMP[0].Info.Description = "The default gateway address for this VM. Leave blank if DHCP is desired."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = "vami"
$PROPERTYTEMP[0].Info.InstanceId = "vRealize_Operations_Manager_Appliance"
$PROPERTYTEMP[0].Info.Id = "DNS"
$PROPERTYTEMP[0].Info.Category = "Networking Properties"
$PROPERTYTEMP[0].Info.Label = "Domain Name Servers"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $True
$PROPERTYTEMP[0].Info.DefaultValue = ""
$PROPERTYTEMP[0].Info.Value = Read-Host "Please provide the DNS servers list in comma seperated format. Example: 192.168.1.32,192.168.1.33"
$PROPERTYTEMP[0].Info.Description = "The domain name server IP Addresses for this VM (comma separated). Leave blank if DHCP is desired."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = "vami"
$PROPERTYTEMP[0].Info.InstanceId = "vRealize_Operations_Manager_Appliance"
$PROPERTYTEMP[0].Info.Id = "ip0"
$PROPERTYTEMP[0].Info.Category = "Networking Properties"
$PROPERTYTEMP[0].Info.Label = "Network 1 IP Address"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $True
$PROPERTYTEMP[0].Info.DefaultValue = ""
$PROPERTYTEMP[0].Info.Value = Read-Host "Please provide the IP address of the vROPs node"
$PROPERTYTEMP[0].Info.Description = "The IP address for this interface. Leave blank if DHCP is desired."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = ""
$PROPERTYTEMP[0].Info.InstanceId = ""
$PROPERTYTEMP[0].Info.Id = "forceIpv6"
$PROPERTYTEMP[0].Info.Category = "User Settings

Please add the amount of disk space required before powering up the node."
$PROPERTYTEMP[0].Info.Label = "IPv6"
$PROPERTYTEMP[0].Info.Type = "boolean"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $True
$PROPERTYTEMP[0].Info.DefaultValue = "False"
$PROPERTYTEMP[0].Info.Value = "False"
$PROPERTYTEMP[0].Info.Description = "Use IPv6. If IPv6 is not available configuration will not succeed."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = "vami"
$PROPERTYTEMP[0].Info.InstanceId = "vRealize_Operations_Manager_Appliance"
$PROPERTYTEMP[0].Info.Id = "searchpath"
$PROPERTYTEMP[0].Info.Category = "Networking Properties"
$PROPERTYTEMP[0].Info.Label = "Domain Search Path"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $True
$PROPERTYTEMP[0].Info.DefaultValue = ""
$PROPERTYTEMP[0].Info.Value = Read-Host "Please provide the domain search path(s). Example contso.com, contso.org"
$PROPERTYTEMP[0].Info.Description = "The domain search path (comma or space separated domain names) for this VM. Leave blank if DHCP is desired."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = "vami"
$PROPERTYTEMP[0].Info.InstanceId = "vRealize_Operations_Manager_Appliance"
$PROPERTYTEMP[0].Info.Id = "netmask0"
$PROPERTYTEMP[0].Info.Category = "Networking Properties"
$PROPERTYTEMP[0].Info.Label = "Network 1 Netmask"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $True
$PROPERTYTEMP[0].Info.DefaultValue = ""
$PROPERTYTEMP[0].Info.Value = Read-Host "Please provde the Network Netmask. Example 255.255.255.0"
$PROPERTYTEMP[0].Info.Description = "The netmask or prefix for this interface. Leave blank if DHCP is desired."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = ""
$PROPERTYTEMP[0].Info.InstanceId = ""
$PROPERTYTEMP[0].Info.Id = "guestinfo.cis.appliance.rc.enabled"
$PROPERTYTEMP[0].Info.Category = "Optional Properties"
$PROPERTYTEMP[0].Info.Label = "Remote Collector"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $False
$PROPERTYTEMP[0].Info.DefaultValue = "false"
$PROPERTYTEMP[0].Info.Value = ""
$PROPERTYTEMP[0].Info.Description = "Automatically configure this node to be used as a remote collector."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = "vami"
$PROPERTYTEMP[0].Info.InstanceId = "vRealize_Operations_Manager_Appliance"
$PROPERTYTEMP[0].Info.Id = "domain"
$PROPERTYTEMP[0].Info.Category = "Networking Properties"
$PROPERTYTEMP[0].Info.Label = "Domain Name"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $True
$PROPERTYTEMP[0].Info.DefaultValue = ""
$PROPERTYTEMP[0].Info.Value = Read-Host "Please provide the Domain Name for this vROPs node. Example contso.com"
$PROPERTYTEMP[0].Info.Description = "The domain name of this VM. Leave blank if DHCP is desired."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = "vm"
$PROPERTYTEMP[0].Info.InstanceId = ""
$PROPERTYTEMP[0].Info.Id = "vmname"
$PROPERTYTEMP[0].Info.Category = ""
$PROPERTYTEMP[0].Info.Label = "vmname"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $False
$PROPERTYTEMP[0].Info.DefaultValue = "vRealize_Operations_Manager_Appliance"
$PROPERTYTEMP[0].Info.Value = ""
$PROPERTYTEMP[0].Info.Description = ""
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = ""
$PROPERTYTEMP[0].Info.InstanceId = ""
$PROPERTYTEMP[0].Info.Id = "vamitimezone"
$PROPERTYTEMP[0].Info.Category = "User Settings

Please add the amount of disk space required before powering up the node."
$PROPERTYTEMP[0].Info.Label = "Timezone setting"
$PROPERTYTEMP[0].Info.Type = @"
string["America/Argentina/Buenos_Aires", "Etc/GMT-1", "Africa/Abidjan", "Africa/Accra", "Africa/Addis_Ababa", "Africa/Algiers", "Africa/Asmara", "Africa/Asmera", "Africa/Bamako", "Africa/Bangui", "Africa/Banjul", "Africa/Bissau", "Africa/Blantyre", "Africa/Brazzaville", "Africa/Bujumbura", "Africa/Cairo", "Africa/Cape Verde", "Africa/Casablanca", "Africa/Ceuta", "Africa/Conakry", "Africa/Dakar", "Africa/Dar_es_Salaam", "Africa/Djibouti", "Africa/Douala", "Africa/El_Aaiun", "Africa/Freetown", "Africa/Gaborone", "Africa/Harare", "Africa/Johannesburg", "Africa/Juba", "Africa/Kampala", "Africa/Khartoum", "Africa/Kigali", "Africa/Kinshasa", "Africa/Lagos", "Africa/Libreville", "Africa/Lome", "Africa/Luanda", "Africa/Lubumbashi", "Africa/Lusaka", "Africa/Malabo", "Africa/Maputo", "Africa/Maseru", "Africa/Mbabane", "Africa/Mogadishu", "Africa/Monrovia", "Africa/Nairobi", "Africa/Ndjamena", "Africa/Niamey", "Africa/Nouakchott", "Africa/Ouagadougou", "Africa/Porto-Novo", "Africa/Sao_Tome", "Africa/Seychelles", "Africa/Timbuktu", "Africa/Tripoli", "Africa/Tunis", "Africa/Windhoek", "America/Adak", "America/Amazon", "America/Anchorage", "America/Anguilla", "America/Antigua", "America/Araguaina", "America/Argentina/Catamarca", "America/Argentina/ComodRivadavia", "America/Argentina/Cordoba", "America/Argentina/Jujuy", "America/Argentina/La_Rioja", "America/Argentina/Mendoza", "America/Argentina/Rio_Gallegos", "America/Argentina/Salta", "America/Argentina/San_Juan", "America/Argentina/San_Luis", "America/Argentina/Tucuman", "America/Argentina/Ushuaia", "America/Aruba", "America/Asuncion", "America/Atikokan", "America/Atka", "America/Bahia", "America/Baker Island", "America/Bahia_Banderas", "America/Barbados", "America/Belem", "America/Belize", "America/Blanc-Sablon", "America/Boa_Vista", "America/Bogota", "America/Boise", "America/Bolivia", "America/Brasilia", "America/Buenos_Aires", "America/Cambridge_Bay", "America/Campo_Grande", "America/Cancun", "America/Caracas", "America/Catamarca", "America/Cayenne", "America/Cayman", "America/Chicago", "America/Chihuahua", "America/Colombia Summer", "America/Colombia", "America/Coral_Harbour", "America/Cordoba", "America/Costa_Rica", "America/Creston", "America/Cuiaba", "America/Curacao", "America/Danmarkshavn", "America/Dawson", "America/Dawson_Creek", "America/Denver", "America/Detroit", "America/Dominica", "America/Edmonton", "America/Eirunepe", "America/El_Salvador", "America/Ensenada", "America/Ecuador", "America/Falkland Islands Standard", "America/Falkland Islands Summer", "America/Falkland Islands", "America/Fernando de Noronha", "America/Fort_Wayne", "America/Fortaleza", "America/Glace_Bay", "America/Godthab", "America/Goose_Bay", "America/Grand_Turk", "America/Grenada", "America/Guadeloupe", "America/Guatemala", "America/Guayaquil", "America/Guyana", "America/Halifax", "America/Havana", "America/Hawaii-Aleutian Daylight", "America/Hawaii-Aleutian Standard", "America/Hermosillo", "America/Indiana/Indianapolis", "America/Indiana/Knox", "America/Indiana/Marengo", "America/Indiana/Petersburg", "America/Indiana/Tell_City", "America/Indiana/Vevay", "America/Indiana/Vincennes", "America/Indiana/Winamac", "America/Indianapolis", "America/Inuvik", "America/Iqaluit", "America/Jamaica", "America/Jujuy", "America/Juneau", "America/Kentucky/Louisville", "America/Kentucky/Monticello", "America/Knox_IN", "America/Kralendijk", "America/La_Paz", "America/Lima", "America/Los_Angeles", "America/Louisville", "America/Lower_Princes", "America/Maceio", "America/Managua", "America/Manaus", "America/Marigot", "America/Martinique", "America/Matamoros", "America/Mazatlan", "America/Mendoza", "America/Menominee", "America/Merida", "America/Metlakatla", "America/Mexico_City", "America/Miquelon", "America/Moncton", "America/Monterrey", "America/Montevideo", "America/Montreal", "America/Montserrat", "America/Nassau", "America/New_York", "America/Nipigon", "America/Nome", "America/Noronha", "America/North_Dakota/Beulah", "America/North_Dakota/Center", "America/North_Dakota/New_Salem", "America/Ojinaga", "America/Panama", "America/Pangnirtung", "America/Paraguay Summer", "America/Paraguay", "America/Paramaribo", "America/Peru", "America/Phoenix", "America/Port_of_Spain", "America/Port-au-Prince", "America/Porto_Acre", "America/Porto_Velho", "America/Puerto_Rico", "America/Rainy_River", "America/Rankin_Inlet", "America/Recife", "America/Regina", "America/Resolute", "America/Rio_Branco", "America/Rosario", "America/Saint Pierre and Miquelon Standard", "America/Santa_Isabel", "America/Santarem", "America/Santiago", "America/Santo_Domingo", "America/Sao_Paulo", "America/Scoresbysund", "America/Shiprock", "America/Sitka", "America/St_Barthelemy", "America/St_Johns", "America/St_Kitts", "America/St_Lucia", "America/St_Thomas", "America/St_Vincent", "America/Suriname", "America/Swift_Current", "America/Tegucigalpa", "America/Thule", "America/Thunder_Bay", "America/Tijuana", "America/Toronto", "America/Tortola", "America/Uruguay Summer", "America/Uruguay Standard", "America/Vancouver", "America/Venezuelan Standard", "America/Virgin", "America/Whitehorse", "America/Winnipeg", "America/Yakutat", "America/Yellowknife", "Antarctica/Casey", "Antarctica/Davis", "Antarctica/DumontDUrville", "Antarctica/Macquarie", "Antarctica/Mawson", "Antarctica/McMurdo", "Antarctica/Palmer", "Antarctica/Rothera", "Antarctica/Showa Station", "Antarctica/South_Pole", "Antarctica/Syowa", "Antarctica/Troll", "Antarctica/Vostok", "Arctic/Longyearbyen", "Asia/Aden", "Asia/Afghanistan", "Asia/Almaty", "Asia/Amman", "Asia/Anadyr", "Asia/Aqtau", "Asia/Aqtobe", "Asia/Armenia", "Asia/Ashgabat", "Asia/Ashkhabad", "Asia/Azerbaijan", "Asia/Baghdad", "Asia/Bahrain", "Asia/Baku", "Asia/Bangkok", "Asia/Beirut", "Asia/Bhutan", "Asia/Bishkek", "Asia/Brunei", "Asia/Calcutta", "Asia/Central Indonesia", "Asia/China Standard", "Asia/China", "Asia/Choibalsan", "Asia/Chongqing", "Asia/Chungking", "Asia/Colombo", "Asia/Dacca", "Asia/Damascus", "Asia/Dhaka", "Asia/Dili", "Asia/Dubai", "Asia/Dumont d'Urville", "Asia/Dushanbe", "Asia/Gaza", "Asia/Gulf Standard", "Asia/Harbin", "Asia/Hebron", "Asia/Ho_Chi_Minh", "Asia/Hong Kong", "Asia/Hovd", "Asia/Indochina", "Asia/Irkutsk", "Asia/Istanbul", "Asia/Jakarta", "Asia/Jayapura", "Asia/Jerusalem", "Asia/Kabul", "Asia/Kamchatka", "Asia/Karachi", "Asia/Kashgar", "Asia/Kathmandu", "Asia/Katmandu", "Asia/Khandyga", "Asia/Khovd", "Asia/Kolkata", "Asia/Krasnoyarsk", "Asia/Kuala_Lumpur", "Asia/Kyrgyzstan", "Asia/Kuching", "Asia/Kuwait", "Asia/Macao", "Asia/Macau", "Asia/Magadan", "Asia/Makassar", "Asia/Malaysia", "Asia/Malaysia Standard", "Asia/Manila", "Asia/Muscat", "Asia/Myanmar", "Asia/Nepal", "Asia/Nicosia", "Asia/Novokuznetsk", "Asia/Novosibirsk", "Asia/Omsk", "Asia/Oral", "Asia/Pakistan Standard", "Asia/Philippine", "Asia/Phnom_Penh", "Asia/Pontianak", "Asia/Pyongyang", "Asia/Qatar", "Asia/Qyzylorda", "Asia/Rangoon", "Asia/Riyadh", "Asia/Saigon", "Asia/Sakhalin", "Asia/Samarkand", "Asia/Seoul", "Asia/Shanghai", "Asia/Singapore", "Asia/South Georgia and the South Sandwich Islands", "Asia/Sri Lanka", "Asia/Taipei", "Asia/Tajikistan", "Asia/Tashkent", "Asia/Tbilisi", "Asia/Tehran", "Asia/Tel_Aviv", "Asia/Thailand Standard", "Asia/Thimbu", "Asia/Thimphu", "Asia/Timor Leste", "Asia/Tokyo", "Asia/Turkmenistan", "Asia/Ujung_Pandang", "Asia/Ulaanbaatar", "Asia/Ulan_Bator", "Asia/Urumqi", "Asia/Ust-Nera", "Asia/Uzbekistan", "Asia/Vientiane", "Asia/Vladivostok", "Asia/Yakutsk", "Asia/Yekaterinburg", "Asia/Yerevan", "Atlantic/Azores", "Atlantic/Bermuda", "Atlantic/Canary", "Atlantic/Cape_Verde", "Atlantic/Faeroe", "Atlantic/Faroe", "Atlantic/Jan_Mayen", "Atlantic/Madeira", "Atlantic/Reykjavik", "Atlantic/South_Georgia", "Atlantic/St_Helena", "Atlantic/Stanley", "Australia/ACT", "Australia/Adelaide", "Australia/Brisbane", "Australia/Broken_Hill", "Australia/Canberra", "Australia/Currie", "Australia/Darwin", "Australia/Eucla", "Australia/Heard and McDonald Islands", "Australia/Hobart", "Australia/LHI", "Australia/Lindeman", "Australia/Lord Howe Standard", "Australia/Lord Howe Summer", "Australia/Melbourne", "Australia/North", "Australia/NSW", "Australia/Perth", "Australia/Queensland", "Australia/South", "Australia/Sydney", "Australia/Tasmania", "Australia/Victoria", "Australia/West", "Australia/Yancowinna", "Brazil/Acre", "Brazil/DeNoronha", "Brazil/East", "Brazil/West", "Canada/Atlantic", "Canada/Central", "Canada/Eastern", "Canada/East-Saskatchewan", "Canada/Mountain", "Canada/Newfoundland", "Canada/Pacific", "Canada/Saskatchewan", "Canada/Yukon", "Caribbean/Eastern Caribbean", "Chile/Continental", "Chile/EasterIsland", "Cuba", "Egypt", "Eire", "Etc/GMT", "Etc/GMT+0", "Etc/UCT", "Etc/Universal", "Etc/UTC", "Etc/Zulu", "Europe/AIX specific equivalent of Central European", "Europe/Amsterdam", "Europe/Andorra", "Europe/Athens", "Europe/Belfast", "Europe/Belgrade", "Europe/Berlin", "Europe/Bratislava", "Europe/British Summer", "Europe/Brussels", "Europe/Bucharest", "Europe/Budapest", "Europe/Busingen", "Europe/Chisinau", "Europe/Copenhagen", "Europe/Dublin", "Europe/Gibraltar", "Europe/Guernsey", "Europe/Helsinki", "Europe/Heure Avancée d'Europe Centrale francised name for CEST", "Europe/Irish Standard", "Europe/Isle_of_Man", "Europe/Istanbul", "Europe/Jersey", "Europe/Kaliningrad", "Europe/Kiev", "Europe/Lisbon", "Europe/Ljubljana", "Europe/London", "Europe/Luxembourg", "Europe/Madrid", "Europe/Malta", "Europe/Mariehamn", "Europe/Minsk", "Europe/Monaco", "Europe/Moscow", "Europe/Nicosia", "Europe/Oslo", "Europe/Paris", "Europe/Podgorica", "Europe/Prague", "Europe/Riga", "Europe/Rome", "Europe/Samara", "Europe/San_Marino", "Europe/Sarajevo", "Europe/Simferopol", "Europe/Skopje", "Europe/Sofia", "Europe/Stockholm", "Europe/Tallinn", "Europe/Tirane", "Europe/Tiraspol", "Europe/Uzhgorod", "Europe/Vaduz", "Europe/Vatican", "Europe/Vienna", "Europe/Vilnius", "Europe/Volgograd", "Europe/Warsaw", "Europe/Zagreb", "Europe/Zaporozhye", "Europe/Zurich", "GB", "GB-Eire", "GMT", "GMT+0", "GMT0", "GMT-0", "Greenwich", "Hongkong", "Iceland", "Indian/Antananarivo", "Indian/Chagos", "Indian/British Indian Ocean", "Indian/Christmas", "Indian/Cocos", "Indian/Comoro", "Indian/Indian Standard", "Indian/Kerguelen", "Indian/Mahe", "Indian/Maldives", "Indian/Mauritius", "Indian/Mayotte", "Indian/Reunion", "Iran", "Israel", "Jamaica", "Japan", "Kwajalein", "Libya", "Mexico/BajaNorte", "Mexico/BajaSur", "Mexico/General", "Navajo", "NZ", "NZ-CHAT", "Pacific/Apia", "Pacific/Auckland", "Pacific/Chamorro", "Pacific/Chatham", "Pacific/Chuuk", "Pacific/Clipperton", "Pacific/Cook Island", "Pacific/Easter Island Standard", "Pacific/Easter Island Summer", "Pacific/Efate", "Pacific/Enderbury", "Pacific/Fakaofo", "Pacific/Fiji", "Pacific/Funafuti", "Pacific/Galapagos", "Pacific/Gambier", "Pacific/Gilbert Island", "Pacific/Guadalcanal", "Pacific/Guam", "Pacific/Honolulu", "Pacific/Johnston", "Pacific/Kiritimati", "Pacific/Kosrae", "Pacific/Kwajalein", "Pacific/Line Islands", "Pacific/Majuro", "Pacific/Marquesas", "Pacific/Marshall Islands", "Pacific/Midway", "Pacific/Nauru", "Pacific/New Caledonia", "Pacific/New Zealand Daylight", "Pacific/New Zealand Standard", "Pacific/Niue", "Pacific/Norfolk", "Pacific/Noumea", "Pacific/Pago_Pago", "Pacific/Palau", "Pacific/Papua New Guinea", "Pacific/Pitcairn", "Pacific/Pohnpei", "Pacific/Ponape", "Pacific/Port_Moresby", "Pacific/Rarotonga", "Pacific/Saipan", "Pacific/Samoa", "Pacific/Solomon Islands", "Pacific/Tahiti", "Pacific/Tarawa", "Pacific/Tokelau", "Pacific/Tongatapu", "Pacific/Truk", "Pacific/Tuvalu", "Pacific/Vanuatu", "Pacific/Wake", "Pacific/Wallis", "Pacific/Yap", "Poland", "Portugal", "PRC", "ROC", "ROK", "Singapore", "Turkey", "UCT", "Universal/Universal Time Coordinated", "US/Alaska", "US/Aleutian", "US/Arizona", "US/Central", "US/Eastern", "US/East-Indiana", "US/Hawaii", "US/Indiana-Starke", "US/Michigan", "US/Mountain", "US/Pacific", "US/Samoa", "UTC", "W-SU", "Zulu"]
"@
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $True
$PROPERTYTEMP[0].Info.DefaultValue = "Etc/UTC"
$PROPERTYTEMP[0].Info.Value = "US/Eastern" #change for your Time Zone
Write-Host "Please Verify the Time Zone after vApp Configuration Completes"
$PROPERTYTEMP[0].Info.Description = "Select the proper timezone setting for this VM or leave default Etc/UTC."
$PROPERTYARRAY += $PROPERTYTEMP
$n = $n + 1

$PROPERTYTEMP = $null
$PROPERTYTEMP = New-Object VMware.Vim.VAppPropertySpec
$PROPERTYTEMP[0].Info = New-Object VMware.Vim.VAppPropertyInfo
$PROPERTYTEMP[0].Info.key = $n
$PROPERTYTEMP[0].Info.ClassId = ""
$PROPERTYTEMP[0].Info.InstanceId = ""
$PROPERTYTEMP[0].Info.Id = "guestinfo.cis.appliance.ssh.enabled"
$PROPERTYTEMP[0].Info.Category = "Optional Properties"
$PROPERTYTEMP[0].Info.Label = "Prevent disabling of SSH"
$PROPERTYTEMP[0].Info.Type = "string"
$PROPERTYTEMP[0].Info.TypeReference = ""
$PROPERTYTEMP[0].Info.UserConfigurable = $False
$PROPERTYTEMP[0].Info.DefaultValue = "false"
$PROPERTYTEMP[0].Info.Value = ""
$PROPERTYTEMP[0].Info.Description = "Use common passwords and setups.
                             Ensure that sshd is configured and running.
                             WARNING: Using this option will result in a less than
                             fully secure installation."
$PROPERTYARRAY += $PROPERTYTEMP

#Add PropertyArray to SPEC
$SPEC.VAppConfig.Property = $PROPERTYARRAY

Write-Host "Writting configuration changes back to VM"
$VM.ExtensionData.ReconfigVM_Task($SPEC)




Write-Host "Setting vApp IP Assignment Configuration"
$IpAssignment = New-Object VMware.Vim.VAppIPAssignmentInfo
$IpAssignment[0].IpAllocationPolicy = "fixedPolicy"
$SupportedIpProtocol = @()
$SupportedIpProtocolTEMP = "IPv4"
$SupportedIpProtocol += $SupportedIpProtocolTEMP
$IpAssignment[0].SupportedIpProtocol = $SupportedIpProtocol
$IpAssignment[0].IpProtocol = "IPv4"
$SPEC.VAppConfig.IpAssignment = $IpAssignment

Write-Host "Setting vApp EULA Configuration"
$SPEC.VAppConfig.Eula = @"
 VMWARE END USER LICENSE AGREEMENT

PLEASE NOTE THAT THE TERMS OF THIS END USER LICENSE AGREEMENT SHALL GOVERN YOUR USE OF THE SOFTWARE, REGARDLESS OF ANY TERMS THAT MAY APPEAR DURING THE INSTALLATION OF THE SOFTWARE.

IMPORTANT-READ CAREFULLY:   BY DOWNLOADING, INSTALLING, OR USING THE SOFTWARE, YOU (THE INDIVIDUAL OR LEGAL ENTITY) AGREE TO BE BOUND BY THE TERMS OF THIS END USER LICENSE AGREEMENT ("EULA").  IF YOU DO NOT AGREE TO THE TERMS OF THIS EULA, YOU MUST NOT DOWNLOAD, INSTALL, OR USE THE SOFTWARE, AND YOU MUST DELETE OR RETURN THE UNUSED SOFTWARE TO THE VENDOR FROM WHICH YOU ACQUIRED IT WITHIN THIRTY (30) DAYS AND REQUEST A REFUND OF THE LICENSE FEE, IF ANY, THAT YOU PAID FOR THE SOFTWARE.

EVALUATION LICENSE.  If You are licensing the Software for evaluation purposes, Your use of the Software is only permitted in a non-production environment and for the period limited by the License Key.  Notwithstanding any other provision in this EULA, an Evaluation License of the Software is provided "AS-IS" without indemnification, support or warranty of any kind, expressed or implied.

1.      DEFINITIONS.

1.1      "Affiliate" means, with respect to a party at a given time, an entity that then is directly or indirectly controlled by, is under common control with, or controls that party, and here "control" means an ownership, voting or similar interest representing fifty percent (50%) or more of the total interests then outstanding of that entity.

1.2     "Documentation" means that documentation that is generally provided to You by VMware with the Software, as revised by VMware from time to time, and which may include end user manuals, operation instructions, installation guides, release notes, and on-line help files regarding the use of the Software.

1.3     "Guest Operating Systems" means instances of third-party operating systems licensed by You, installed in a Virtual Machine and run using the Software.

1.4     "Intellectual Property Rights" means all worldwide intellectual property rights, including without limitation, copyrights, trademarks, service marks, trade secrets, know how, inventions, patents, patent applications, moral rights and all other proprietary rights, whether registered or unregistered.

1.5     "License" means a license granted under Section 2.1 (General License Grant).

1.6     "License Key" means a serial number that enables You to activate and use the Software.

1.7     "License Term" means the duration of a License as specified in the Order.

1.8     "License Type" means the type of License applicable to the Software, as more fully described in the Order.

1.9 "Open Source Software" or "OSS" means software components embedded in the Software and provided under separate license terms, which can be found either in the open_source_licenses.txt file (or similar file) provided within the Software or at www.vmware.com/download/open_source.html.

1.10 "Order" means a purchase order, enterprise license agreement, or other ordering document issued by You to VMware or a VMware authorized reseller that references and incorporates this EULA and is accepted by VMware as set forth in Section 4 (Order).
1.11 "Product Guide" means the current version of the VMware Product Guide at the time of Your Order, copies of which are found at www.vmware.com/download/eula.

1.12 "Support Services Terms" means VMware's then-current support policies, copies of which are posted at www.vmware.com/support/policies.

1.13    "Software" means the VMware Tools and the VMware computer programs listed on VMware's commercial price list to which You acquire a license under an Order, together with any software code relating to the foregoing that is provided to You pursuant to a support and subscription service contract and that is not subject to a separate license agreement.

1.14 "Territory" means the country or countries in which You have been invoiced; provided, however, that if You have been invoiced within any of the European Economic Area member states, You may deploy the corresponding Software throughout the European Economic Area.

1.15 "Third Party Agent" means a third party delivering information technology services to You pursuant to a written contract with You.

1.16    "Virtual Machine" means a software container that can run its own operating system and execute applications like a physical machine.

1.17    "VMware" means VMware, Inc., a Delaware corporation, if You are purchasing Licenses or services for use in the United States and VMware International Limited, a company organized and existing under the laws of Ireland, for all other purchases.
1.18    "VMware Tools" means the suite of utilities and drivers, Licensed by VMware under the "VMware Tools" name, that can be installed in a Guest Operating System to enhance the performance and functionality of a Guest Operating System when running in a Virtual Machine.

2.              LICENSE GRANT.

2.1     General License Grant.  VMware grants to You a non-exclusive, non-transferable (except as set forth in Section 12.1 (Transfers; Assignment)) license to use the Software and the Documentation during the period of the license and within the Territory, solely for Your internal business operations, and subject to the provisions of the Product Guide. Unless otherwise indicated in the Order, licenses granted to You will be perpetual, will be for use of object code only, and will commence on either delivery of the physical media or the date You are notified of availability for electronic download.

2.2     Third Party Agents.  Under the License granted to You in Section 2.1 (General License Grant) above, You may permit Your Third Party Agents to access, use and/or operate the Software on Your behalf for the sole purpose of delivering services to You, provided that You will be fully responsible for Your Third Party Agents' compliance with terms and conditions of this EULA and any breach of this EULA by a Third Party Agent shall be deemed to be a breach by You.

2.3       Copying Permitted.  You may copy the Software and Documentation as necessary to install and run the quantity of copies licensed, but otherwise for archival purposes only.

2.4     Benchmarking.  You may use the Software to conduct internal performance testing and benchmarking studies. You may only publish or otherwise distribute the results of such studies to third parties as follows:  (a) if with respect to VMware's Workstation or Fusion products, only if You provide a copy of Your study to benchmark@vmware.com prior to distribution;   (b) if with respect to any other Software, only if VMware has reviewed and approved of the methodology, assumptions and other parameters of the study  (please contact VMware at benchmark@vmware.com to request such review and approval) prior to such publication and distribution.

2.5     VMware Tools.  You may distribute the VMware Tools to third parties solely when installed in a Guest Operating System within a Virtual Machine. You are liable for compliance by those third parties with the terms and conditions of this EULA.

2.6     Open Source Software.  Notwithstanding anything herein to the contrary, Open Source Software is licensed to You under such OSS's own applicable license terms, which can be found in the open_source_licenses.txt file, the Documentation or as applicable, the corresponding source files for the Software available at www.vmware.com/download/open_source.html. These OSS license terms are consistent with the license granted in Section 2 (License Grant), and may contain additional rights benefiting You.  The OSS license terms shall take precedence over this EULA to the extent that this EULA imposes greater restrictions on You than the applicable OSS license terms. To the extent the license for any Open Source Software requires VMware to make available to You the corresponding source code and/or modifications (the "Source Files"), You may obtain a copy of the applicable Source Files from VMware's website at www.vmware.com/download/open_source.html or by sending a written request, with Your name and address to: VMware, Inc., 3401 Hillview Avenue, Palo Alto, CA 94304, United States of America. All requests should clearly specify:  Open Source Files Request, Attention: General Counsel.  This offer to obtain a copy of the Source Files is valid for three years from the date You acquired this Software.

3.      RESTRICTIONS; OWNERSHIP.

3.1     License Restrictions.  Without VMware's prior written consent, You must not, and must not allow any third party to: (a) use Software in an application services provider, service bureau, or similar capacity for third parties, except that You may use the Software to deliver hosted services to Your Affiliates; (b) disclose to any third party the results of any benchmarking testing or comparative or competitive analyses of VMware's Software done by or on behalf of You, except as specified in Section 2.4 (Benchmarking); (c) make available Software in any form to anyone other than Your employees or contractors reasonably acceptable to VMware and require access to use Software on behalf of You in a matter permitted by this EULA, except as specified in Section 2.2 (Third Party Agents); (d) transfer or sublicense Software or Documentation to an Affiliate or any third party, except as expressly permitted in Section 12.1 (Transfers; Assignment); (e) use Software in conflict with the terms and restrictions of the Software's licensing model and other requirements specified in Product Guide and/or VMware quote; (f) except to the extent permitted by applicable mandatory law, modify, translate, enhance, or create derivative works from the Software, or  reverse engineer, decompile, or otherwise attempt to derive source code from the Software, except as specified in Section 3.2 (Decompilation); (g) remove any copyright or other proprietary notices on or in any copies of Software; or (h) violate or circumvent any technological restrictions within the Software or specified in this EULA, such as via software or services.

3.2     Decompilation.  Notwithstanding the foregoing, decompiling the Software is permitted to the extent the laws of the Territory give You the express right to do so to obtain information necessary to render the Software interoperable with other software; provided, however, You must first request such information from VMware, provide all reasonably requested information to allow VMware to assess Your claim, and VMware may, in its discretion, either provide such interoperability information to You, impose reasonable conditions, including a reasonable fee, on such use of the Software, or offer to provide alternatives to ensure that VMware's proprietary rights in the Software are protected and to reduce any adverse impact on VMware's proprietary rights.

3.3     Ownership.  The Software and Documentation, all copies and portions thereof, and all improvements, enhancements, modifications and derivative works thereof, and all Intellectual Property Rights therein, are and shall remain the sole and exclusive property of VMware and its licensors. Your rights to use the Software and Documentation shall be limited to those expressly granted in this EULA and any applicable Order.  No other rights with respect to the Software or any related Intellectual Property Rights are implied.  You are not authorized to use (and shall not permit any third party to use) the Software, Documentation or any portion thereof except as expressly authorized by this EULA or the applicable Order.  VMware reserves all rights not expressly granted to You. VMware does not transfer any ownership rights in any Software.

3.4     Guest Operating Systems.  Certain Software allows Guest Operating Systems and application programs to run on a computer system. You acknowledge that You are responsible for obtaining and complying with any licenses necessary to operate any such third-party software.

4.      ORDER.  Your Order is subject to this EULA.  No Orders are binding on VMware until accepted by VMware.  Orders for Software are deemed to be accepted upon VMware's delivery of the Software included in such Order. Orders issued to VMware do not have to be signed to be valid and enforceable.

5.      RECORDS AND AUDIT.  During the License Term for Software and for two (2) years after its expiration or termination, You will maintain accurate records of Your use of the Software sufficient to show compliance with the terms of this EULA. During this period, VMware will have the right to audit Your use of the Software to confirm compliance with the terms of this EULA. That audit is subject to reasonable notice by VMware and will not unreasonably interfere with Your business activities. VMware may conduct no more than one (1) audit in any twelve (12) month period, and only during normal business hours. You will reasonably cooperate with VMware and any third party auditor and will, without prejudice to other rights of VMware, address any non-compliance identified by the audit by promptly paying additional fees. You will promptly reimburse VMware for all reasonable costs of the audit if the audit reveals either underpayment of more than five (5%) percent of the Software fees payable by You for the period audited, or that You have materially failed to maintain accurate records of Software use.

6.      SUPPORT AND SUBSCRIPTION SERVICES.  Except as expressly specified in the Product Guide, VMware does not provide any support or subscription services for the Software under this EULA.  You have no rights to any updates, upgrades or extensions or enhancements to the Software developed by VMware unless you separately purchase VMware support or subscription services.  These support or subscription services are subject to the Support Services Terms.

7.    WARRANTIES.

7.1 Software Warranty, Duration and Remedy.  VMware warrants to You that the Software will, for a period of ninety (90) days following notice of availability for electronic download or delivery ("Warranty Period"), substantially conform to the applicable Documentation, provided that the Software: (a) has been properly installed and used at all times in accordance with the applicable Documentation; and (b) has not been modified or added to by persons other than VMware or its authorized representative. VMware will, at its own expense and as its sole obligation and Your exclusive remedy for any breach of this warranty, either replace that Software or correct any reproducible error in that Software reported to VMware by You in writing during the Warranty Period. If VMware determines that it is unable to correct the error or replace the Software, VMware will refund to You the amount paid by You for that Software, in which case the License for that Software will terminate.

7.2 Software Disclaimer of Warranty.  OTHER THAN THE WARRANTY ABOVE, AND TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, VMWARE AND ITS SUPPLIERS MAKE NO OTHER EXPRESS WARRANTIES UNDER THIS EULA, AND DISCLAIM ALL IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT, AND ANY WARRANTY ARISING BY STATUTE, OPERATION OF LAW, COURSE OF DEALING OR PERFORMANCE, OR USAGE OF TRADE. VMWARE AND ITS LICENSORS DO NOT WARRANT THAT THE SOFTWARE WILL OPERATE UNINTERRUPTED OR THAT IT WILL BE FREE FROM DEFECTS OR THAT IT WILL MEET YOUR REQUIREMENTS.

8.     INTELLECTUAL PROPERTY INDEMNIFICATION.

8.1 Defense and Indemnification.  Subject to the remainder of this Section 8 (Intellectual Property Indemnification), VMware shall defend You against any third party claim that the Software infringes any patent, trademark or copyright of such third party, or misappropriates a trade secret (but only to the extent that the misappropriation is not a result of Your actions) under the laws of: (a) the United States and Canada; (b) the European Economic Area; (c) Australia; (d) New Zealand; (e) Japan; or (f) the People's Republic of China, to the extent that such countries are part of the Territory for the License ("Infringement Claim") and indemnify You from the resulting costs and damages finally awarded against You to such third party by a court of competent jurisdiction or agreed to in settlement. The foregoing obligations are applicable only if You:  (i) promptly notify VMware in writing of the Infringement Claim; (ii) allow VMware sole control over the defense for the claim and any settlement negotiations; and (iii) reasonably cooperate in response to VMware requests for assistance.  You may not settle or compromise any Infringement Claim without the prior written consent of VMware.
8.2 Remedies.  If the alleged infringing Software become, or in VMware's opinion be likely to become, the subject of an Infringement Claim, VMware will, at VMware's option and expense, do one of the following:  (a) procure the rights necessary for You to make continued use of the affected Software; (b) replace or modify the affected Software to make it non-infringing; or (c) terminate the License to the affected Software and discontinue the related support services, and, upon Your certified deletion of the affected Software, refund: (i) the fees paid by You for the License to the affected Software, less straight-line depreciation over a three (3) year useful life beginning on the date such Software was delivered; and (ii) any pre-paid service fee attributable to related support services to be delivered after the date such service is stopped. Nothing in this Section 8.2 (Remedies) shall limit VMware's obligation under Section 8.1 (Defense and Indemnification) to defend and indemnify You, provided that You replace the allegedly infringing Software upon VMware's making alternate Software available to You and/or You discontinue using the allegedly infringing Software upon receiving VMware's notice terminating the affected License.
8.3 Exclusions.  Notwithstanding the foregoing, VMware will have no obligation under this Section 8 (Intellectual Property Indemnification) or otherwise with respect to any claim based on:  (a) a combination of Software with non-VMware products (other than non-VMware products that are listed on the Order and used in an unmodified form); (b) use for a purpose or in a manner for which the Software was not designed; (c) use of any older version of the Software when use of a newer VMware version would have avoided the infringement; (d) any modification to the Software made without VMware's express written approval; (e) any claim that relates to open source software or freeware technology or any derivatives or other adaptations thereof that is not embedded by VMware into Software listed on VMware's commercial price list; or (f) any Software provided on a no charge, beta or evaluation basis.  THIS SECTION 8 (INTELLECTUAL PROPERTY INDEMNIFICATION) STATES YOUR SOLE AND EXCLUSIVE REMEDY AND VMWARE'S ENTIRE LIABILITY FOR ANY INFRINGEMENT CLAIMS OR ACTIONS.

9. LIMITATION OF LIABILITY.

9.1 Limitation of Liability.  TO THE MAXIMUM EXTENT MANDATED BY LAW, IN NO EVENT WILL VMWARE AND ITS LICENSORS BE LIABLE FOR ANY LOST PROFITS OR BUSINESS OPPORTUNITIES, LOSS OF USE, LOSS OF REVENUE, LOSS OF GOODWILL, BUSINESS INTERRUPTION, LOSS OF DATA, OR ANY INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES UNDER ANY THEORY OF LIABILITY, WHETHER BASED IN CONTRACT, TORT, NEGLIGENCE, PRODUCT LIABILITY, OR OTHERWISE.  BECAUSE SOME JURISDICTIONS DO NOT ALLOW THE EXCLUSION OR LIMITATION OF LIABILITY FOR CONSEQUENTIAL OR INCIDENTAL DAMAGES, THE PRECEDING LIMITATION MAY NOT APPLY TO YOU.  VMWARE'S AND ITS LICENSORS' LIABILITY UNDER THIS EULA WILL NOT, IN ANY EVENT, REGARDLESS OF WHETHER THE CLAIM IS BASED IN CONTRACT, TORT, STRICT LIABILITY, OR OTHERWISE, EXCEED THE GREATER OF THE LICENSE FEES YOU PAID FOR THE SOFTWARE GIVING RISE TO THE CLAIM OR $5000. THE FOREGOING LIMITATIONS SHALL APPLY REGARDLESS OF WHETHER VMWARE OR ITS LICENSORS HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF WHETHER ANY REMEDY FAILS OF ITS ESSENTIAL PURPOSE.

9.2 Further Limitations.  VMware's licensors shall have no liability of any kind under this EULA and VMware's liability with respect to any third party software embedded in the Software shall be subject to Section 9.1 (Limitation of Liability).  You may not bring a claim under this EULA more than eighteen (18) months after the cause of action arises.

10.     TERMINATION.
10.1    EULA Term. The term of this EULA begins on the notice of availability for electronic download or delivery of the Software and continues until this EULA is terminated in accordance with this Section 10.
10.2    Termination for Breach.  VMware may terminate this EULA effective immediately upon written notice to You if: (a) You fail to pay any portion of the fees under an applicable Order within ten (10) days after receiving written notice from VMware that payment is past due; or (b) You breach any other provision of this EULA and fail to cure within thirty (30) days after receipt of VMware's written notice thereof.
10.3    Termination for Insolvency.  VMware may terminate this EULA effective immediately upon written notice to You if You: (a) terminate or suspend your business; (b) become insolvent, admit in writing Your inability to pay Your debts as they mature, make an assignment for the benefit of creditors; or become subject to control of a trustee, receiver or similar authority; or (c) become subject to any bankruptcy or insolvency proceeding.
10.4    Effect of Termination.  Upon VMware's termination of this EULA: (a) all Licensed rights to all Software granted to You under this EULA will immediately cease; and (b) You must cease all use of all Software, and return or certify destruction of all Software and License Keys (including copies) to VMware, and return, or if requested by VMware, destroy, any related VMware Confidential Information in Your possession or control and certify in writing to VMware that You have fully complied with these requirements. Any provision will survive any termination or expiration if by its nature and context it is intended to survive, including Sections 1 (Definitions), 2.6 (Open Source Software), 3 (Restrictions; Ownership), 5 (Records and Audit), 7.2 (Software Disclaimer of Warranty), 9 (Limitation of Liability), 10 (Termination), 11 (Confidential Information) and 12 (General).

11.     CONFIDENTIAL INFORMATION.

11.1    Definition.  "Confidential Information"  means information or materials provided by one party ("Discloser") to the other party ("Recipient") which are in tangible form and labelled "confidential" or the like, or, information which a reasonable person knew or should have known to be confidential.  The following information shall be considered Confidential Information whether or not marked or identified as such:  (a) License Keys; (b) information regarding VMware's pricing, product roadmaps or strategic marketing plans; and (c) non-public materials relating to the Software.

11.2    Protection.  Recipient may use Confidential Information of Discloser; (a) to exercise its rights and perform its obligations under this EULA; or (b) in connection with the parties' ongoing business relationship.  Recipient will not use any Confidential Information of Discloser for any purpose not expressly permitted by this EULA, and will disclose the Confidential Information of Discloser only to the employees or contractors of Recipient who have a need to know such Confidential Information for purposes of this EULA and who are under a duty of confidentiality no less restrictive than Recipient's duty hereunder.  Recipient will protect Confidential Information from unauthorized use, access, or disclosure in the same manner as Recipient protects its own confidential or proprietary information of a similar nature but with no less than reasonable care.
11.3 Exceptions.  Recipient's obligations under Section 11.2 (Protection) with respect to any Confidential Information will terminate if Recipient can show by written records that such information:  (a) was already known to Recipient at the time of disclosure by Discloser; (b) was disclosed to Recipient by a third party who had the right to make such disclosure without any confidentiality restrictions; (c) is, or through no fault of Recipient has become, generally available to the public; or (d) was independently developed by Recipient without access to, or use of, Discloser's Information.  In addition, Recipient will be allowed to disclose Confidential Information to the extent that such disclosure is required by law or by the order of a court of similar judicial or administrative body, provided that Recipient notifies Discloser of such required disclosure promptly and in writing and cooperates with Discloser, at Discloser's request and expense, in any lawful action to contest or limit the scope of such required disclosure.
11.4    Data Privacy.  You agree that VMware may process technical and related information about Your use of the Software which may include internet protocol address, hardware identification, operating system, application software, peripheral hardware, and non-personally identifiable Software usage statistics to facilitate the provisioning of updates, support, invoicing or online services and may transfer such information to other companies in the VMware worldwide group of companies from time to time. To the extent that this information constitutes personal data, VMware shall be the controller of such personal data. To the extent that it acts as a controller, each party shall comply at all times with its obligations under applicable data protection legislation.

12.     GENERAL.

12.1    Transfers; Assignment.  Except to the extent transfer may not legally be restricted or as permitted by VMware's transfer and assignment policies, in all cases following the process set forth at www.vmware.com/support/policies/licensingpolicies.html, You will not assign this EULA, any Order, or any right or obligation herein or delegate any performance without VMware's prior written consent, which consent will not be unreasonably withheld. Any other attempted assignment or transfer by You will be void. VMware may use its Affiliates or other sufficiently qualified subcontractors to provide services to You, provided that VMware remains responsible to You for the performance of the services.

12.2    Notices.  Any notice delivered by VMware to You under this EULA will be delivered via mail, email or fax.

12.3    Waiver.  Failure to enforce a provision of this EULA will not constitute a waiver.
12.4     Severability.  If any part of this EULA is held unenforceable, the validity of all remaining parts will not be affected.
12.5    Compliance with Laws; Export Control; Government Regulations. Each party shall comply with all laws applicable to the actions contemplated by this EULA. You acknowledge that the Software is of United States origin, is provided subject to the U.S. Export Administration Regulations, may be subject to the export control laws of the applicable territory, and that diversion contrary to applicable export control laws is prohibited. You represent that (1) you are not, and are not acting on behalf of, (a) any person who is a citizen, national, or resident of, or who is controlled by the government of any country to which the United States has prohibited export transactions; or (b) any person or entity listed on the U.S. Treasury Department list of Specially Designated Nationals and Blocked Persons, or the U.S. Commerce Department Denied Persons List or Entity List; and (2) you will not permit the Software to be used for, any purposes prohibited by law, including, any prohibited development, design, manufacture or production of missiles or nuclear, chemical or biological weapons. The Software and accompanying documentation are deemed to be "commercial computer software" and "commercial computer software documentation", respectively, pursuant to DFARS Section 227.7202 and FAR Section 12.212(b), as applicable.  Any use, modification, reproduction, release, performing, displaying or disclosing of the Software and documentation by or for the U.S. Government shall be governed solely by the terms and conditions of this EULA.
12.6    Construction.  The headings of sections of this EULA are for convenience and are not to be used in interpreting this EULA. As used in this EULA, the word 'including' means "including but not limited to".
12.7    Governing Law.  This EULA is governed by the laws of the State of California, United States of America (excluding its conflict of law rules), and the federal laws of the United States. To the extent permitted by law, the state and federal courts located in Santa Clara County, California will be the exclusive jurisdiction for disputes arising out of or in connection with this EULA. The U.N. Convention on Contracts for the International Sale of Goods does not apply.
12.8    Third Party Rights.  Other than as expressly set out in this EULA, this EULA does not create any rights for any person who is not a party to it, and no person who is not a party to this EULA may enforce any of its terms or rely on any exclusion or limitation contained in it.
12.9    Order of Precedence.  In the event of conflict or inconsistency among the Product Guide, this EULA and the Order, the following order of precedence shall apply: (a) the Product Guide, (b) this EULA and (c) the Order. With respect to any inconsistency between this EULA and an Order, the terms of this EULA shall supersede and control over any conflicting or additional terms and conditions of any Order, acknowledgement or confirmation or other document issued by You.
12.10  Entire Agreement.  This EULA, including accepted Orders and any amendments hereto, and the Product Guide contain the entire agreement of the parties with respect to the subject matter of this EULA and supersede all previous or contemporaneous communications, representations, proposals, commitments, understandings and agreements, whether written or oral, between the parties regarding the subject matter hereof.  This EULA may be amended only in writing signed by authorized representatives of both parties.
12.11  Contact Information.  Please direct legal notices or other correspondence to VMware, Inc., 3401 Hillview Avenue, Palo Alto, California 94304, United States of America, Attention: Legal Department.
"@

Write-Host "Setting vApp OvfEnvironmentTransport Configuration"
$SPEC.VAppConfig.OvfEnvironmentTransport = "com.vmware.guestInfo"

Write-Host "Setting vApp Install Boot Required Configuration"
$SPEC.VAppConfig.InstallBootRequired = $False

Write-Host "Setting vApp Boot Stop Delay Configuration"
$SPEC.VAppConfig.InstallBootStopDelay = 0

###Write SPEC back to VM
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Writing updated VM SPEC back to Virtual Machine"
Write-Host "Writting configuration changes back to VM"
$vm.ExtensionData.ReconfigVM_Task($spec)
Write-Host "Completed SPEC configuration chanages. Writing SPEC back to VM $VMNAME"
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
