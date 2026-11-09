<#
    .NOTES
	Created by:		Russell Hamker
	Date:			November 9,2026
	Version:		2.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

	.SYNOPSIS
		This script removes specified VIBs from a selected VMHost

	.DESCRIPTION
		Use this script to prep a VMHost for NSX-T

	.EXAMPLE
	#Example - Single Host
	$VCSA = "hamvc01.hamker.local"
	$VCSAUSERNAME = "rhamker@hamker.local"
	$VIBListtoRemove = "qcnic","qfle3i","qfle3f","qfle3"
	$VMHost = "hamesxi02.hamker.local"
	If(!$CREDENTIAL){
		$CREDENTIAL = Get-Credential -Message "Please Provide VCSA Creds" -Username $VCSAUSERNAME
	}
	.\Remove_Extra_VIBs_from_VMHost.ps1 `
	-VCSA $VCSA `
	-Credential $CREDENTIAL `
	-VIBListtoRemove $VIBListtoRemove `
	-VMHost $VMHost

	.EXAMPLE
	#Example - Single Host with Restart
	$VCSA = "hamvc01.hamker.local"
	$VCSAUSERNAME = "rhamker@hamker.local"
	$VIBListtoRemove = "qcnic","qfle3i","qfle3f","qfle3"
	$VMHost = "hamesxi02.hamker.local"
	$RestartVMHost = $true
	If(!$CREDENTIAL){
		$CREDENTIAL = Get-Credential -Message "Please Provide VCSA Creds" -Username $VCSAUSERNAME
	}
	.\Remove_Extra_VIBs_from_VMHost.ps1 `
	-VCSA $VCSA `
	-Credential $CREDENTIAL `
	-VIBListtoRemove $VIBListtoRemove `
	-VMHost $VMHost `
	-RestartVMHost $RestartVMHost

	.EXAMPLE
	#Example - Multiple Hosts with Restart - Does each host in Sync order
	$VMHostList = "hamesxi03.hamker.local","hamesxi04.hamker.local"
	$VCSA = "hamvc01.hamker.local"
	$VCSAUSERNAME = "rhamker@hamker.local"
	$VIBListtoRemove = "qcnic","qfle3i","qfle3f","qfle3"
	$RestartVMHost = $true
	If(!$CREDENTIAL){
		$CREDENTIAL = Get-Credential -Message "Please Provide VCSA Creds" -Username $VCSAUSERNAME
	}
	ForEach($VMHost in $VMHostList){
		.\Remove_Extra_VIBs_from_VMHost.ps1 `
		-VCSA $VCSA `
		-Credential $CREDENTIAL `
		-VIBListtoRemove $VIBListtoRemove `
		-VMHost $VMHost `
		-RestartVMHost $RestartVMHost
	}
#>
param(
	[Parameter(Mandatory=$false)][string]$VCSA,
	[Parameter(Mandatory=$false)][System.Management.Automation.PSCredential]$Credential,
	[Parameter(Mandatory=$true)][string[]]$VIBListtoRemove,
	[Parameter(Mandatory=$false)][string]$VMHost,
	[Parameter(Mandatory=$false)][boolean]$RestartVMHost
)

##Check if Modules are installed, if so load them, else install them
if (Get-InstalledModule -Name VMware.PowerCLI -MinimumVersion 11.4) {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module VMware PowerCLI required minimum version was found previously installed"
	Write-Host "Importing PowerShell Module VMware PowerCLI"
	Import-Module -Name VMware.VimAutomation.Core
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
$LOCATION = Get-Location

If(!$VCSA){
	##Select VCSA
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Start Time - $STARTTIME"
	##Get VCSA
	$VCSA = Read-Host "Please provide the VCSA FQDN"
	Write-Host "VCSA Selected is $VCSA"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
}

##Provide Credentials
#CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
If(!$Credential)
{
	Write-Host "Please Provide VCSA Administrator based Credentials for VCSA $VCSA"
	$Credential = Get-Credential -Message "Please Provide VCSA Creds"
	Write-Host "Credential UserName provided is:"$Credential.UserName
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
$vCenter = Connect-VIServer -server $VCSA -Credential $Credential -ErrorAction Stop
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

If(!$VMHost){
##Select CLUSTER
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Select Cluster on vCenter $VCSA"
$CLUSTER = Get-Cluster | Sort-Object Name
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
$choice = Read-Host "On which Cluster do you want to look at?"
$CLUSTER = Get-Cluster $CLUSTER[$choice]
Write-Host "You have selected Cluster $CLUSTER on vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select VMHost
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Select VMHost on vCenter $VCSA in Cluster $CLUSTER"
$VMHOST = Get-Cluster $CLUSTER| Get-VMHost | Sort-Object Name
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
$choice = Read-Host "Which VMHost do you wish to review?"
$VMHOST = Get-VMHost $VMHOST[$choice]
$HOSTNAME = $VMHOST.NAME
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
}Else{
	$VMHOSTOBJ = Get-VMHost $VMHOST
	$HOSTNAME = $VMHOSTOBJ.NAME
}

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $HOSTNAME + "_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $LOCATION.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $LOCATION.path+"\Log\"+$LOGFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Check if VMHost is part of a Cluster (DRS)
If($VMHOSTOBJ.ConnectionState -eq "Maintenance"){
	Write-Host "VMHost now in Maintenance Mode - $($VMHOSTOBJ.Name)"
}Else{
	$CLUSTER = $VMHOSTOBJ | Get-Cluster -ErrorAction SilentlyContinue
	$VSANENABLED = $CLUSTER.VsanEnabled
	$MaintenanceOnly = $true
	$Shutdown = $false
	$RunAsync = $false
	If($MaintenanceOnly -eq $true -or $Reboot -eq $true -or $Shutdown -eq $true){
		#VMHost Maintenance Mode
		If($VMHOSTOBJ.ConnectionState -ne "Maintenance|NotResponding"){
			Write-Host "Putting VMHost Into Maintenance Mode - $VMHOSTOBJ "
			$COUNT = 0
			$COUNTMAX = 3
			Do{
				If($Shutdown -eq $true){
					If($RunAsync -eq $true){
						Write-Host "Async Set to TRUE, Not waiting for Maintenance Confirmation on VMHost - $VMHOSTOBJ"
						If($VSANENABLED -eq $true){
							Write-Host "vSAN Node Detected. Doing vSAN Full Data Migration for Maintenance Mode."
							$VMHOSTOBJ | Set-VMHost -State Maintenance -VsanDataMigrationMode Full -RunAsync -Confirm:$false
						}Else{
							$VMHOSTOBJ | Set-VMHost -State Maintenance -RunAsync -Confirm:$false
						}
					}Else{
						If($VSANENABLED -eq $true){
							Write-Host "vSAN Node Detected. Doing vSAN Full Data Migration for Maintenance Mode."
							$VMHOSTOBJ | Set-VMHost -State Maintenance -VsanDataMigrationMode Full -Confirm:$false

						}Else{
							$VMHOSTOBJ | Set-VMHost -State Maintenance -Confirm:$false
						}
					}
				}Else{
					If($RunAsync -eq $true){
						Write-Host "Async Set to TRUE, Not waiting for Maintenance Confirmation on VMHost - $VMHOSTOBJ"
						If($CLUSTER.Count -ne 0){
							If($VSANENABLED -eq $true){
								Write-Host "vSAN Node Detected. Doing vSAN Full Data Migration for Maintenance Mode."
								$VMHOSTOBJ | Set-VMHost -State Maintenance -VsanDataMigrationMode Full -RunAsync -Evacuate:$true -Confirm:$false
							}Else{
								$VMHOSTOBJ | Set-VMHost -State Maintenance -RunAsync -Evacuate:$true -Confirm:$false
							}
						}Else{
							If($VSANENABLED -eq $true){
								Write-Host "vSAN Node Detected. Doing vSAN Full Data Migration for Maintenance Mode."
								$VMHOSTOBJ | Set-VMHost -State Maintenance -VsanDataMigrationMode Full -RunAsync -Confirm:$false
							}Else{
								$VMHOSTOBJ | Set-VMHost -State Maintenance -RunAsync -Confirm:$false
							}
						}
					}Else{
						#check if it is part of a clsuter
						If($CLUSTER.Count -ne 0){
							If($VSANENABLED -eq $true){
								$VMHOSTOBJ | Set-VMHost -State Maintenance -VsanDataMigrationMode EnsureAccessibility -Evacuate:$true -Confirm:$false
							}Else{
								$VMHOSTOBJ | Set-VMHost -State Maintenance -Evacuate:$true -Confirm:$false
							}
						}Else{
							If($VSANENABLED -eq $true){
								$VMHOSTOBJ | Set-VMHost -State Maintenance -VsanDataMigrationMode Full -Confirm:$false
							}Else{
								$VMHOSTOBJ | Set-VMHost -State Maintenance -Confirm:$false
							}
						}
					}
				}
				$VMHOSTOBJ = Get-VMHost $VMHost
				$COUNT++
			}Until($VMHOSTOBJ.ConnectionState -eq "Maintenance" -Or $COUNT -gt $COUNTMAX)
			If($COUNT -gt $COUNTMAX){
				Write-Error "Count not successfully place into Maintenance Mode - $($VMHOSTOBJ.Name)" -ErrorAction Stop
			}
		}
		If($VMHOSTOBJ.ConnectionState -eq "Maintenance"){
			Write-Host "VMHost now in Maintenance Mode - $($VMHOSTOBJ.Name)"
		}
		If($VMHOSTOBJ.ConnectionState -eq "NotResponding"){
			Write-Host "VMHost now in Not Responding State - $($VMHOSTOBJ.Name)"
		}
	}
}

#ESXCLI
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Connecting ESXCLI to VMHost $VMHOST" -ForegroundColor green
$esxcli = Get-EsxCli -VMHost $VMHOST -V2

#Get NIC Driver Name(s)
Write-Host "Getting NIC VIBs in Use"
$NicVIBinUse = (get-vmhost $VMHOST | Get-VMHostNetworkAdapter).ExtensionData.Driver | Sort-Object | get-Unique

#Get FC Driver Name
Write-Host "Getting FC VIBs in Use"
$FCVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type FibreChannel).Driver | Sort-Object | Get-Unique

#Get Block Driver Name
Write-Host "Getting Block VIBs in Use"
$BlockVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type Block).Driver | Sort-Object | Get-Unique

#Get SCSI Driver Name
Write-Host "Getting SCSI VIBs in Use"
$SCSIVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type ParallelScsi).Driver

#Get VIB List
Write-Host "Getting All VIBs installed on Host"
$VIBSONHOST = $esxcli.software.vib.list.invoke()

#Compare VIB lists and prevent the actively used VIBs from being removed
#NIC
ForEach($VIB in $NicVIBinUse)
{
	If($VIBLISTTOREMOVE -eq $VIB)
	{
		Write-Host "VIB Driver found in list that is in use"
		$VIBLISTTOREMOVE = $VIBLISTTOREMOVE | Where-Object {$_ -ne $VIB}
	}
}
#FC
ForEach($VIB in $FCVIBinUse)
{
	If($VIBLISTTOREMOVE -eq $VIB)
	{
		Write-Host "VIB Driver found in list that is in use"
		$VIBLISTTOREMOVE = $VIBLISTTOREMOVE | Where-Object {$_ -ne $VIB}
	}
}
#Block
ForEach($VIB in $BlockVIBinUse)
{
	If($VIBLISTTOREMOVE -eq $VIB)
	{
		Write-Host "VIB Driver found in list that is in use"
		$VIBLISTTOREMOVE = $VIBLISTTOREMOVE | Where-Object {$_ -ne $VIB}
	}
}
#SCSI
ForEach($VIB in $SCSIVIBinUse)
{
	If($VIBLISTTOREMOVE -eq $VIB)
	{
		Write-Host "VIB Driver found in list that is in use"
		$VIBLISTTOREMOVE = $VIBLISTTOREMOVE | Where-Object {$_ -ne $VIB}
	}
}

#List VIBS to remove
Write-Host "$VMHOST will have these VIBs Removed:"
Write-Output $VIBLISTTOREMOVE | Sort-Object | Format-Table
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Remove VIBs from Host
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Starting VIB Removal for VMHost $VMHOST in Cluster $CLUSTER"
ForEach ($VIB in $VIBLISTTOREMOVE)
{
	If($VIBSONHOST.Name -Contains $VIB)
	{
		#List VIB to remove
		Write-Host "VIB Removal starting for $VIB" -ForegroundColor green
		Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
		
		#Create Arg List
		$esxcliRemoveVibArgs = $esxcli.software.vib.remove.CreateArgs()
		$esxcliRemoveVibArgs.vibname = $VIB
		If($VIB -eq "net-mlx4-core"){$esxcliRemoveVibArgs.noliveinstall = $true}
		
		#Remove VIB
		$esxcli.software.vib.remove.Invoke($esxcliRemoveVibArgs)
		Write-Host "VIB Removal completed for $VIB" -ForegroundColor green
		Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	}
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Completed removing VIBS for VMHost $VMHOST"
Write-Host "Disconnecting ESXCLI from VMHOST $VMHOST" -ForegroundColor green
$esxcli = $null
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Restart VMHost If flag is true
If($RestartVMHost -eq $True){
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "VMHost Reboot Flag Selected, Rebooting VMHost - $VMHOSTOBJ"
	$RunAsync = $false
	If($RunAsync -eq $true){
		Write-Host "RunAsync set to TRUE, Not waiting for Restart to Complete"
		$VMHOSTOBJ | Restart-VMHost -Force -RunAsync -Confirm:$false
	}Else{
		$VMHOSTOBJ | Restart-VMHost -Force -Confirm:$false
	}

	#Wait for VMHost to show NotResponding
	Do{
		$VMHOSTOBJ = Get-VMHost $VMHost
		$COUNT = 0
		$MAXCOUNT = 20
		If($VMHOSTOBJ.ConnectionState -ne "NotResponding"){
			Write-Host "VMHost not back in NotResponding - Waiting - $($VMHOSTOBJ.Name)"
			Start-Sleep -Seconds 30
			$COUNT++
		}
		If($COUNT -gt $MAXCOUNT){
			Write-Error "Timeout occured waiting for VMHost to be NotResponding" -ErrorAction Stop
		}
	}Until($VMHOSTOBJ.ConnectionState -eq "NotResponding" -Or $COUNT -gt $COUNTMAX)
	If($COUNT -gt $COUNTMAX){
		Write-Error "VMHost could not enter NotResponding State - $($VMHOSTOBJ.Name)"
	}
	If($VMHOSTOBJ.ConnectionState -eq "NotResponding"){
		Write-Host "VMHost Now NotRespondong (rebooting) - $($VMHOSTOBJ.Name)" -ForegroundColor Green
	}

	#Wait for 5 minutes
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Waiting for VMHost to Reboot - $($VMHOSTOBJ.Name)" -Foregroundcolor Green
	$WaitSeconds = 300
	$Activity = "Waiting for $($WaitSeconds) Seconds"
	1..$WaitSeconds | ForEach-Object { $percent = $_ * 100 / $WaitSeconds 
		Write-Progress -Activity $Activity -Status "$($WaitSeconds - $_) Seconds remaining..." -PercentComplete $percent 
		Start-Sleep -Seconds 1
	}
	Write-Progress -Completed -Activity "make progress bar disappear" -ErrorAction SilentlyContinue
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")

	#Get VMHost Status and wait for host to be in Maintenance
	Do{
		$VMHOSTOBJ = Get-VMHost $VMHost
		$COUNT = 0
		$MAXCOUNT = 10
		If($VMHOSTOBJ.ConnectionState -ne "Maintenance"){
			Write-Host "VMHost not back in Mainteance Mode - Waiting - $($VMHOSTOBJ.Name)"
			Start-Sleep -Seconds 30
			$COUNT++
		}
	}Until($VMHOSTOBJ.ConnectionState -eq "Maintenance" -Or $COUNT -gt $MAXCOUNT)
	If($COUNT -gt $MAXCOUNT){
		Write-Error "Timeout occured waiting for VMHost to come back online - $($VMHOSTOBJ.Name)" -ErrorAction Stop
	}
	If($VMHOSTOBJ.ConnectionState -eq "Maintenance"){
		Write-Host "VMHost has returned to Maintenance Mode - $($VMHOSTOBJ.Name)" -ForegroundColor Green
		Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	}

	#Bring VMHost out of Maintenance Mode
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Bringing VMHost out of Maintenance Mode on VMHost - $VMHOSTOBJ"
	$VMHOSTOBJ = Get-VMHost $VMHost
	If($VMHOSTOBJ.ConnectionState -ne "Connected"){
		$COUNT = 0
		$MAXCOUNT = 10
		Do{
			$VMHOSTOBJ | Set-VMHost -State Connected -Confirm:$false
			$VMHOSTOBJ = Get-VMHost $VMHost
			If($VMHOSTOBJ.ConnectionState -ne "Connected"){
				Write-Warning "VMHost not out of Maintenance - $VMHOSTOBJ"
				Start-Sleep -Seconds 30
				$COUNT++
			}
			
		}Until($VMHOSTOBJ.ConnectionState -eq "Connected" -Or $COUNT -gt $MAXCOUNT)
		If($COUNT -gt $MAXCOUNT){
			Write-Error "Reached Maximum Attempts to put VMHost into Connected Status - $VMHOSTOBJ" -ErrorAction Stop
		}
	}
	If($VMHOSTOBJ.ConnectionState -eq "Connected"){
		Write-Host "VMHost now in Connected Status - $VMHOSTOBJ"
		Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	}
}
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
disconnect-viserver $vCenter -confirm:$false
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
Write-Host "VMHost $VMHOST"
Write-Host "Cluster $CLUSTER"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
