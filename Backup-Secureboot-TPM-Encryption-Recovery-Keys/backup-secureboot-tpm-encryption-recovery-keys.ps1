<#
.NOTES
	Created by:		Russell Hamker
	Date:			April 2, 2026
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

.SYNOPSIS
	This script will backup SecureBoot TPM Encryption Recovery Keys

.DESCRIPTION
	Use this script to backup SecureBoot TPM Encryption Recovery Keys
	
	Reference:
	https://knowledge.broadcom.com/external/article/323401/tpm-encryption-recovery-key-backup-warni.html

.EXAMPLE
	#Example - VMHost List
	$VCSA = "hamvc01.hamker.local"
	$VMHostList = @("hamesxi01.hamker.local")
	./backup-secureboot-tpm-encryption-recovery-keys.ps1 `
	-VCSA $VCSA `
	-VMHostList $VMHostList

.EXAMPLE
	#Example - Cluster
	$VCSA = "hamvc01.hamker.local"
	$Cluster = "MyCluster"
	./backup-secureboot-tpm-encryption-recovery-keys.ps1 `
	-VCSA $VCSA `
	-Cluster $Cluster

#>

param(
	[Parameter(Mandatory=$true)][String]$VCSA,
	[Parameter(Mandatory=$false)][String]$Cluster,
	[Parameter(Mandatory=$false)][Array]$VMHostList,
	[Parameter(Mandatory=$false)][Int]$ValidationTimeout
)

# If no cluster or VMHostList Error
If(!$Cluster -and !$VMHostList){
	Write-Error "Please Specify Cluster or VMHostList and then rerun script" -ErrorAction Stop
}

# Set Default of 30 minutes for Validation Time Out if not set
If($ValidationTime -lt 1){
	$ValidationTimeout = 30
}

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

#Import Module
Import-Module VMware.PowerCLI

##Get Current Path
$LOCATION = Get-Location

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
If($Cluster){
	$LOGFILENAME = $LOGDATE + "-$Cluster-log" + ".txt"
}Else{
	$LOGFILENAME = $LOGDATE + "-backup-up-tpm-recovery-keys-log" + ".txt"
}
#Create Log Folder
$LogFolder = $LOCATION.path+"\log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $LOCATION.path+"\log\"+$LOGFILENAME

##Clean up old logs
Write-Host "Cleaning up logs that are over 30 days old"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Get-ChildItem –Path $LogFolder -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-30))} | Remove-Item -Recurse -Force -Confirm:$false

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")

#Validate that the Self Signed VCSA Certificates do not cause an issue with PowerCLI Connecting to the VCSA
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User -Confirm:$false | Out-Null


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

##Disconnect from any open VMware Sessions,
#This can cause problems if there are any
Write-Host "Disconnecting from any Open VCSA Sessions"
TRY
{Disconnect-VIServer * -Confirm:$false | Out-Null}
CATCH
{Write-Host "No Open VCSA Sessions found"}

##Connect to VMware VCSA Resource
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$COUNT = 0
Do{
	Write-Host "Connecting to VCSA - $($VCSA)"
	$VISERVER = Connect-VIServer -server $VCSA -Credential $MyCredential -ErrorAction SilentlyContinue
	If(!$VISERVER.Name){
		Write-Host "Could NOT Connect to VCSA - $VCSA"
		$WaitSeconds = 60
		$Activity = "Waiting for $($WaitSeconds) Seconds"
		1..$WaitSeconds | ForEach-Object { $percent = $_ * 100 / $WaitSeconds 
			Write-Progress -Activity $Activity -Status "$($WaitSeconds - $_) Seconds remaining..." -PercentComplete $percent 
			Start-Sleep -Seconds 1
		}
		$COUNT ++
		Write-Host "Could Not Connect to VCSA - $($VCSA)" -Foregroundcolor Red
		Write-Host "Count - $COUNT"
	}
}Until($VISERVER.Name -Or $COUNT -eq $ValidationTimeout)
If($COUNT -eq $ValidationTimeout){
	Write-Error "Could not connect to VCSA - $($VCSA), Please check Network and DNS Resolution." -ErrorAction Stop
}
Write-Progress -Completed -Activity "make progress bar disappear" -ErrorAction SilentlyContinue

#Document all Hosts in the Cluster
If($Cluster){
	Write-Host "Gathering VMHost List for Cluster - $($Cluster)"
	$VMHostList = (Get-Cluster $Cluster | Get-VMHost | Select-Object Name | Sort-Object Name).Name
	If($VMhostList.count -lt 1){
		Write-Error "Could not successfully gather VMHost List" -ErrorAction Stop
	}
}Else{
	Write-Host "Gathering VMHost List for:"
	Write-Host $VMHostList
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Set up the Array for Output
$OutputArray = @()

#Run for each host in a cluster
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting SecureBoot TPM Encryption Keys"
ForEach($VMHost in $VMHostList){
	# Document each VMHost
	Write-Host "Starting Export of SecureBoot TPM Encryption Keys - $($VMHost)"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	
	# Set Up Temporary Array
	$TempArray = $null
	$TempArray = "" | Select-Object Name, Key, RecoveryId

	# Backup 
	Write-Host "Backing Up TPM Encryption Recovery Keys - $($VMHOST)"
	$esxcli = Get-EsxCli -VMHost $VMHOST -V2
	$KEYEXPORT = $null
	$KEYEXPORT = $esxcli.system.settings.encryption.recovery.list.Invoke()
	
	# Add Key to Array
	$TempArray.Name = $VMHost
	$TempArray.Key = $KEYEXPORT.Key
	$TempArray.RecoveryId = $KEYEXPORT.RecoveryID
	
	# Check Of TPM Encryption Recovery Key Backup Alarm
	Write-Host "Checking for TPM Encryption Recovery Key Backup Alarm - $($VMHost)"
	$VMHostObj = $null
	$VMHostObj = Get-VMHost $VMHost
	$VMHostObj | Where-Object { $_.ExtensionData.TriggeredAlarmState.OverallStatus -ne "Green" } | ForEach-Object {
		$hostName = $_.Name
		$TriggeredAlarm = $null
		$TriggeredAlarm = $_.ExtensionData.TriggeredAlarmState | Where-Object {(Get-View $_.Alarm).Info.Name -like "*TPM Encryption Recovery Key Backup*"}
	}
	
	# If Alarm Exists, clear It
	If($TriggeredAlarm.Count -gt 0){
		Write-Warning " Alarm -> TPM Encryption Recovery Key Backup Alarm found on VMHost - $($VMHost)"
		$AlarmObj = New-Object Vmware.Vim.ManagedObjectReference
		$AlarmObj.type = $TriggeredAlarm.Alarm.Type
		$AlarmObj.value = $TriggeredAlarm.Alarm.Value
		$Alarm = Get-View $AlarmObj
		$AlarmManager = Get-View AlarmManager
		$AlarmHost = $VMHostObj | Get-View 
		
		# Ack Alarm
		Write-Host "Acknowledging Alarm -> TPM Encryption Recovery Key Backup Alarm on VMHost - $($VMHost)"
		$AlarmManager.AcknowledgeAlarm($Alarm.MoRef, $AlarmHost.MoRef)
		$AlarmManager.ClearTriggeredAlarms($Alarm.MoRef, $AlarmHost.MoRef)
		
		# Clear Alarm
		Write-Host "Clearing Triggered Alarm -> TPM Encryption Recovery Key Backup Alarm on VMHost - $($VMHost)"
		<# This commented out code does not perm clear error. Comes back after maintenance mode.
		$AlarmDefinition = Get-AlarmDefinition -Name "TPM Encryption Recovery Key Backup Alarm"
		$AlarmId = ($AlarmDefinition).Id
		# Disable/Enable alarm to Clear - Does not perm clear error. Comes back after maintenance mode/reboot.
		$VMHostObj.ExtensionData.TriggeredAlarmState | `
		Where-Object Alarm -eq $AlarmId | `
		ForEach-Object -Process {
			$AlarmManager.DisableAlarm( $_.Alarm,$_.Entity)
			$AlarmManager.EnableAlarm( $_.Alarm,$_.Entity)
		}
		#>
		# Only method to properly clear alarm - clears for all hosts first time
		$filter = New-Object VMware.Vim.AlarmFilterSpec
		$filter.Status = [VMware.Vim.ManagedEntityStatus]::$($TriggeredAlarm.OverallStatus) #gray green yellow red
		$filter.TypeEntity = [VMware.Vim.AlarmFilterSpecAlarmTypeByEntity]::entityTypeHost #entityTypeAll entityTypeHost entityTypeVm
		$filter.TypeTrigger = [vmware.vim.AlarmFilterSpecAlarmTypeByTrigger]::triggerTypeEvent #triggerTypeAll triggerTypeEvent triggerTypeMetric
		$AlarmManager.ClearTriggeredAlarms($filter)
	
	}Else{
		Write-Host "Alarm -> TPM Encryption Recovery Key Backup Alarm NOT found on VMHost - $($VMHost)"
	}
	
	#Add Temp Array to Output Array
	$OutputArray += $TempArray
	
	# Document each VMHost
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Completed Export of SecureBoot TPM Encryption Keys - $($VMHost)" -Foregroundcolor Green
}

##Specify Export File Info
If($Cluster){
	$ExportFileName = $LOGDATE + "-$Cluster-backup-up-tpm-recovery-keys" + ".csv"
}Else{
	$ExportFileName = $LOGDATE + "-backup-up-tpm-recovery-keys" + ".csv"
}
#Create Log Folder
$ExportFolder = $LOCATION.path+"\export"
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}
#Specify Export File
$ExportFile = $LOCATION.path+"/export/"+$ExportFileName

## Output Array to CSV
Write-Host "Outputing Backup to path:"
$OutputArray | Sort-Object Name | Export-Csv -Path $ExportFile -NoTypeInformation -ErrorAction Stop
Write-Output $ExportFile

##Disconnect from vCenter
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from vCenter"
Disconnect-ViServer $VCSA -confirm:$false
If($NSXSERVER){
	Write-Host "Disconnecting from NSX Manager"
	Disconnect-NSXServer -NSXServer $NSXSERVER -Confirm:$false
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Document Script Total Run time
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$STARTTIMESW.STOP()
$ENDTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
Write-Host "Start Time - $STARTTIME"
Write-Host "End Time - $ENDTIME"
Write-Host "Total Script Time:"$STARTTIMESW.Elapsed.TotalSeconds"Seconds"
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
If($Cluster){
	Write-Host "Script Completed for $($VCSA) - $($Cluster)"
}Else{
	Write-Host "Script Completed for $($VCSA)"
	Write-Host $VMHostList
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
