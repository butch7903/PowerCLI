<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			November 19, 2021
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will set downtime in icinga, place host into maintenance mode
		reboot the host, and put it back into service.

	.DESCRIPTION
		Use this script to reboot all hosts in a cluster
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

Function Disconnect-VMSerialPort($VMLIST)
{
	IF($VMLIST.Count -gt 1)
	{
		ForEach($VMName in $VMLIST)
		{	
			$VM = Get-VM $VMName
			$DEVICES = $VM.ExtensionData.Config.Hardware.Device
			FOREACH($DEVICE in $DEVICES)
			{
				IF($DEVICE.GetType().Name -eq "VirtualSerialPort")
				{
					IF($DEVICE.Connectable.Connected -eq $true)
					{
						Write-Host "Serial Device Found Connected on VM: $VM, Disconnecting..."
						$DEV = New-Object VMware.Vim.VirtualDeviceConfigSpec
						#add edit remove
						$DEV.Operation = "edit"
						$DEV.Device = New-Object VMware.Vim.VirtualSerialPort
						$DEV.Device.Key = $DEVICE.Key
						$DEV.Device.ControllerKey = $DEVICE.ControllerKey
						$DEV.Device.UnitNumber += $DEVICE.UnitNumber
						$DEV.Device.DeviceInfo += $DEVICE.DeviceInfo
						$DEV.Device.Backing += $DEVICE.Backing
						$DEV.Device.Connectable += $DEVICE.Connectable
						$DEV.Device.Connectable.Connected = $false
						$DEV.Device.Connectable.StartConnected = $false
						$SPEC = New-Object VMware.Vim.VirtualMachineConfigSpec
						$SPEC.DeviceChange += $DEV
						$VM.ExtensionData.ReconfigVM($SPEC)
						$DEVICEUpdated = $VM.ExtensionData.Config.Hardware.Device | Where {$_.Key -eq $DEVICE.Key}
						#Write-Output $DEVICEUpdated
						Write-Output $DEVICEUpdated.Connectable
					}Else{
						Write-Host "No Serial Device Found Connected on VM: $VM"
					}
				}
			}
		}
	}
	IF($VMLIST.Count -eq 1)
	{	
		$VM = Get-VM $VMLIST
		$DEVICES = $VM.ExtensionData.Config.Hardware.Device
		FOREACH($DEVICE in $DEVICES)
		{
			IF($DEVICE.GetType().Name -eq "VirtualSerialPort")
			{
				IF($DEVICE.Connectable.Connected -eq $true)
				{
					Write-Host "Serial Device Found Connected on VM: $VM, Disconnecting..."
					$DEV = New-Object VMware.Vim.VirtualDeviceConfigSpec
					#add edit remove
					$DEV.Operation = "edit"
					$DEV.Device = New-Object VMware.Vim.VirtualSerialPort
					$DEV.Device.Key = $DEVICE.Key
					$DEV.Device.ControllerKey = $DEVICE.ControllerKey
					$DEV.Device.UnitNumber += $DEVICE.UnitNumber
					$DEV.Device.DeviceInfo += $DEVICE.DeviceInfo
					$DEV.Device.Backing += $DEVICE.Backing
					$DEV.Device.Connectable += $DEVICE.Connectable
					$DEV.Device.Connectable.Connected = $false
					$DEV.Device.Connectable.StartConnected = $false
					$SPEC = New-Object VMware.Vim.VirtualMachineConfigSpec
					$SPEC.DeviceChange += $DEV
					$VM.ExtensionData.ReconfigVM($SPEC)
					$DEVICEUpdated = $VM.ExtensionData.Config.Hardware.Device | Where {$_.Key -eq $DEVICE.Key}
					#Write-Output $DEVICEUpdated
					Write-Output $DEVICEUpdated.Connectable
				}Else{
					Write-Host "No Serial Device Found Connected on VM: $VM"
				}
			}
		}
	}
}

#Examples
#$VMLIST = Get-VM
#Disconnect-VMSerialPort $VMLIST
#Disconnect-VMSerialPort (Get-VM $VMNAMEHERE)
#Disconnect-VMSerialPort (Get-VMHost $VMHOSTHERE | Get-VM $VMNAMEHERE)

Function Set-IcingaDowntime{
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[Boolean]$MatchExactName,
	[Parameter(Mandatory=$true)]
	[string]$HostToDT,
	[Parameter(Mandatory=$true)]
	[string]$Author,
	[Parameter(Mandatory=$true)]
	[string]$Comment,
	[Parameter(Mandatory=$true)]
	[datetime]$StartTime,
	[Parameter(Mandatory=$true)]
	[datetime]$EndTime,
	[Parameter(Mandatory=$true)]
	[Boolean]$Children,
	[Parameter(Mandatory=$true)]
	[Boolean]$AllServices
) #end param

# Allow TLS 1.2. Old powershell (.net) uses TLS 1.0 only. Icinga2 >2.10 needs TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'

###Trust all certificates
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#Set $Child
If($Children -eq $False){$Child = "DowntimeNonTriggeredChildren"}
If($Children -eq $True){$Child = "DowntimeTriggeredChildren"}

#Set AllServices
If($AllServices -eq $false){$Services = "false"}
If($AllServices -eq $true){$Services = "true"}

#Set Start/End Times
$start_time = (Get-Date (Get-Date $StartTime).ToUniversalTime() -UFormat %s).split(".", 2)[0]
$end_time =  (Get-Date (Get-Date $EndTime).ToUniversalTime() -UFormat %s).split(".", 2)[0]

If($MatchExactName -eq $true)
{
$body = "{
`n    `"type`": `"Host`", 
`n    `"filter`": `"host.name == filterHost`",
`n    `"filter_vars`": {
`n        `"filterHost`": `"$HostToDT`"
`n    }, 
`n    `"start_time`": `"$start_time`", 
`n    `"end_time`": `"$end_time`", 
`n    `"author`": `"$Author`", 
`n    `"comment`": `"$Comment`", 
`n    `"fixed`": true,
`n    `"child_options`": `"$Child`",
`n    `"all_services`": $Services
`n}"
}

If($MatchExactName -eq $false)
{
$body = "{
`n    `"type`": `"Host`", 
`n    `"filter`": `"match(`\`"*$HostToDT*`\`", host.name)`",
`n    `"start_time`": `"$start_time`", 
`n    `"end_time`": `"$end_time`", 
`n    `"author`": `"$Author`", 
`n    `"comment`": `"$Comment`", 
`n    `"fixed`": true,
`n    `"child_options`": `"$Child`",
`n    `"all_services`": $Services
`n}"
}

#Set Standard API Call Info
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Authorization", "Basic cGxhdG9wc19kdDpKRkR4OXNLc2lsUk1iMHB5bXU=")
$headers.Add("Content-Type", "application/json")

#Complete API Call
$response = Invoke-RestMethod 'https://prod-mon-icinga-sv2-p0.ironport.com:5665/v1/actions/schedule-downtime' -Method 'POST' -Headers $headers -Body $body | ConvertTo-Json

#Parse Response
If($response)
{
	$ARRAY = @()
	$RESPONESLIST = ($response |ConvertFrom-Json).Results | Sort Name
	ForEach($RESP in $RESPONESLIST)
	{
		#Cleaning up response
		$TEMP = "" | Select name,status,legacy_id,code,child_downtimes,services_downtimes
		$TEMP.child_downtimes = $RESP.child_downtimes
		$TEMP.code = $RESP.code
		$TEMP.legacy_id = $RESP.legacy_id
		$TEMP.name = ($RESP.name).Split('!')[0]
		$TEMP.services_downtimes = $RESP.services_downtimes
		$TEMP.status = ($RESP.status).Split("'")[0]
		#Add Temp to Array
		$ARRAY += $TEMP
	}
	#Output full response
	Write-Output $ARRAY
}Else{
	Write-Host "$HostToDT not found in Icinga"
}
}

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$pwd = pwd

##Setting CSV File Location 
$CSVFILELOCATION = $pwd.path

#Provide Credentials
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
If(!$MyCredential)
{
	Write-Host "Please Provide VCSA Administrator based Credentials for the VCSAs"
	$MyCredential = Get-Credential -Message "Please Provide VCSA Creds"
	Write-Host "Credential UserName provided is:"$MyCredential.UserName
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

$VCSA = read-host "Please provide the FQDN of the VCSA"

$RFC = read-host "Please provide RFC
Example: RFC-33450"


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
Connect-CISserver -server $VCSA -Credential $MyCredential
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select CLUSTER
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select Cluster on vCenter $VCSA"
$CLUSTER = Get-Cluster | Sort Name
$countCL = 0   
Write-Host " " 
Write-Host "Clusters: " 
Write-Host " " 
foreach($oC in $CLUSTER)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "On which Cluster do you want to reboot?"
$CLUSTER = Get-Cluster $CLUSTER[$choice]
Write-Host "You have selected Cluster $CLUSTER on vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select VMHost
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select VMHost on vCenter $VCSA"
$VMHOST = Get-Cluster $CLUSTER| Get-VMHost | Sort Name
$countCL = 0   
Write-Host " " 
Write-Host "VMHost: " 
Write-Host " " 
foreach($oC in $VMHOST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which VMHost do you wish to export the Host Profile from?"
$VMHOSTLIST = get-vmhost $VMHOST[$choice]
Write-Host "You have selected 
VMHost $VMHOSTLIST
vCenter $VCSA
"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Reboot Cluster
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Rebooting VMHosts in Cluster $CLUSTER on vCenter $VCSA"
#$VMHOSTLIST = Get-Cluster $CLUSTER | Get-VMHost | Where {$_.ConnectionState -eq "Connected"} |Sort Name
ForEach($VMHost in $VMHOSTLIST)
{
	Write-Host "Starting VMHost $VMHOST"
	
	##Disconnect Serial on all VMs on $VMHOST
	Write-Host "Disconnecting serial ports from all VMs on $VMHOST"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Disconnect-VMSerialPort (Get-VMHost $VMHOST | Get-VM | Sort Name)
	
	##Disconnect ISOs on all VMs
	Write-Host "Disconnecting ISOs"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Get-VMHost $VMHOST | Get-VM | Get-CDDrive | where {$_.IsoPath -ne $null} | Set-CDDrive -NoMedia -Confirm:$False
	
	##Maintenance Mode Host
	Write-Host "Entering Maintenance Mode on $VMHOST"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Set-VMHost $VMHOST -State maintenance -Evacuate | Out-Null
	
	##Setup Downtime on Host
	#Set-IcingaDowntime -MatchExactName $true -Author "rhamker" -Comment "RFC-33450" -StartTime "06:30" -EndTime "10:00" -Children $true -HostToDT "dev-util-nap5-3.ironport.com"
	$CURRENTDATE = Get-Date
	#$HOUR = $CURRENTDATE.Hour
	#$MIN = $CURRENTDATE.Minute
	#$STARTTIME = "$HOUR:$MIN"
	$STARTTIME = [datetime]$currentdate
	$ENDTIME = [datetime]$STARTTIME.AddHours(2)
	#$ENDHOUR = $HOUR.Add
	Write-Host "Setting Icinga Downtime for $VMHOST"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Set-IcingaDowntime -MatchExactName $true -Author ($MyCredential.UserName) -Comment $RFC -StartTime $STARTTIME -EndTime $ENDTIME -Children $true -$AllServices $true -HostToDt ($VMHOST.Name)
	
	##Reboot Host
	Write-Host "Rebooting VMHost $VMHOST"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Restart-VMHost $VMHOST -confirm:$false | Out-Null
	
	##Wait for Server to show as down
	Write-Host "Waiting for $VMHOST to show down"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	do {
	sleep 90
	$ServerState = (get-vmhost $VMHOST).ConnectionState
	}
	while ($ServerState -ne "NotResponding")
	Write-Host "$VMHOST is Down"
	
	##Wait for server to reboot
	Write-Host "Waiting for $VMHost to reboot"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	do {
	sleep 60
	$ServerState = (get-vmhost $VMHost).ConnectionState
	Write-Host "Waiting for Reboot to Complete on $VMHOST..."
	}
	while ($ServerState -ne "Maintenance")
	Write-Host "$VMHOST is back up"
	
	## Exit maintenance mode
	Write-Host "Exiting Maintenance mode on $VMHOST"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Set-VMhost $VMHOST -State Connected | Out-Null
	Write-Host "** Reboot Complete for $VMHOST **"
}


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