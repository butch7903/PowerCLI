<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			January 7, 2021
	Version:		2.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script automates the reporting of what VMs were affected by a VMHost Failure / HA Event

	.DESCRIPTION
		Use this script to document what VMs were affected and when

	.NOTES
		This script requires a VMware PowerCLI minimum version 11.4 or greater

	.TROUBLESHOOTING
		
#>

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

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

##Set Variables
##Get Current Path
$pwd = pwd
##If answerfile exists, Import it for use or create one.
$AnswerFile = $pwd.path+"\"+"AnswerFile.csv"
If (Test-Path $AnswerFile){
##Import File
Write-Host "Answer file found, importing answer file"$AnswerFile
$Answer = Import-Csv $AnswerFile
ForEach($Line in $Answer)
{
	$VERSION = $Line.Version
	Write-Host "Version specified in file is:"$Version
	$SUBVERSION = $Line.SubVersion
	Write-Host "SubVersion specified in file is:"$SubVersion
	$VCENTER = $Line.vCenter
	Write-Host "vCenter specified in file is:"$vCenter
	$ALARMNAME = $Line.AlarmName
	Write-Host "vCenter HA Alarm name to monitor for is:"$ALARMNAME
	$COMMENTS = $Line.COMMENTS
	Write-Host "Comments for script:"$COMMENTS
	$TIMEZONE = $Line.TimeZone
	Write-Host "Time Zone specified in file is:"$TimeZone
	$SmtpServer = $Line.SmtpServer
	Write-Host "SMTP Server will be: "$SmtpServer
	$MsgFrom = $Line.MsgFrom
	Write-Host "Emails will be sent from: "$MsgFrom
	$MsgTo = $Line.MsgTo
	Write-Host "Emails will be sent to: "$MsgTo
	$USEBACKUPPASSWORD = $Line.UseBackupPassword
	
	Write-Host "Continuing..."
	Start-Sleep -Seconds 2
}
}
Else {
$Answers_List = @()
$Answers="" | Select Version,SubVersion,vCenter,AlarmName,Comments,TimeZone,SmtpServer,MsgFrom,MsgTo
Write-Host "Answer file NOT found. Please input information to continue."
$Version = "2"
$Answers.Version = $Version
$SubVersion = "0"
$Answers.SubVersion = $SubVersion
$vCenter = Read-Host "Please input the FQDN or IP of your VCSA
Example: hamvc01.hamker.local"
$Answers.vCenter = $vCenter
$ALARMNAME = Read-Host "Please Provide the name of your HA Alarm
Example: Host HA Failure"
$Answers.AlarmName = $ALARMNAME
$COMMENTS = Read-Host "Input Comments.
Example: This script was updated on xx per xx
(OPTIONAL) (Leave blank if you do not wish to use this)
"
$Answers.Comments = $COMMENTS
$TIMEZONES = @("Central Standard Time","Eastern Standard Time","Mountain Standard Time","Pacific Standard Time","UTC")
If($TIMEZONES.Count -gt 1)
{
   $TIMEZONE = $TIMEZONES | Out-GridView -Title 'Select Time Zone of Scripting Server Server' -OutputMode Single
}else {$TIMEZONE = "Central Standard Time"}
<#
$TIMEZONE = Read-Host "Input Time Zone of Script Server. This is where the script is run from.
Examples: Central Standard Time,Eastern Standard Time,Mountain Standard Time,Pacific Standard Time,UTC"
WHILE("Central Standard Time","Eastern Standard Time","Mountain Standard Time","Pacific Standard Time","UTC" -notcontains $TIMEZONE)
{
	$TIMEZONE = Read-Host "Input Time Zone
	Examples: Central Standard Time,Eastern Standard Time,Mountain Standard Time,Pacific Standard Time,UTC"
}
#>
$Answers.TIMEZONE = $TIMEZONE
$SMTPSERVER = Read-Host "Type in a SMTP Server IP or FQDN for Email Report:
Example: smtp.contso.com 10.1.1.1
"
$Answers.SmtpServer = $SMTPSERVER
$MSGFROM = Read-Host "Type in the from Email From Address
Example: PowerCLI@domain.com
"
$Answers.MsgFrom = $MSGFROM
$MSGTO = Read-Host "Type in the list of Email Addresses to Send the Report to
Example: user@domain.com 
Note: For multiple emails do comma seperated: test@test.com,test2@test.com
"
$Answers.MsgTo = $MSGTO

$Answers_List += $Answers
$Answers_List | Format-Table -AutoSize
Write-Host "Exporting Information to File"$AnswerFile
$Answers_List | Export-CSV -NoTypeInformation $AnswerFile
}


##Create Secure AES Keys for User and Password Management
$KeyFile = $pwd.path+"\"+"AES.key"
If (Test-Path $KeyFile){
Write-Host "AES File Exists"
$Key = Get-Content $KeyFile
Write-Host "Continuing..."
}
Else {
$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | out-file $KeyFile
}

##Create Secure XML Credential File for vCenter
$MgrCreds = $pwd.path+"\"+"MgrCreds.xml"
If (Test-Path $MgrCreds){
Write-Host "MgrCreds.xml file found"
Write-Host "Continuing..."
$ImportObject = Import-Clixml $MgrCreds
$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
$MyCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
}
Else {
$newPScreds = Get-Credential -message "Enter vCenter admin creds here:"
#$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
#$rng.GetBytes($Key)
$exportObject = New-Object psobject -Property @{
    UserName = $newPScreds.UserName
    Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
}
$exportObject | Export-Clixml MgrCreds.xml
$MyCredential = $newPScreds
}

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}
Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\Log\"+$LOGFILENAME

##################################Start of Scritp#########################################################

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Clean up old Log Files
#Delete all Log Files older than 5 day(s)
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Attempting to remove files older than 5 days"
$Daysback = "-5"
$CurrentDateRemoval = Get-Date
$DatetoDelete = $CurrentDateRemoval.AddDays($Daysback)
Get-ChildItem $LogFolder| Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item -Confirm:$false
Write-Host "Completed attempting to remove files older than 5 days"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#List Settings
#Being stated 2nd time after Transcript has started to document info
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Settings will be: "
Write-Host "Version specified in file is: 		"$VERSION
Write-Host "SubVersion specified in file is: 	"$SUBVERSION
Write-Host "VCSA specified in file is: 		"$VCENTER
Write-Host "Time Zone is:		 		"$TIMEZONE
Write-Host "Comments are: 		"$COMMENTS
Write-Host "SMTP Server will be: 			"$SMTPSERVER
Write-Host "Emails will be sent from: 		"$MSGFROM
Write-Host "Emails will be sent to: 		"$MSGTO
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
Write-Host "Disconnecting from any Open CIS vCenter Server Sessions"
if($global:DefaultCisServers)
{
	Disconnect-CisServer * -Confirm:$false
}
ELSE{
	Write-Host "No Open CIS Server Sessions found"
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Connect to vCenter Server
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Connecting to vCenter "$vCenter
Connect-VIServer -server $vCenter -Credential $MyCredential
Write-Host "Connected to VIServer "$vCenter
Write-Host "Waiting 10 Seconds before beginning processes"
Start-Sleep -Seconds 10
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Get HA Alarm Definition
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Getting Alarm Definition Data"
$ALARM = Get-AlarmDefinition -Name $ALARMNAME | Select *
$ALARM
#Get Alarm ID Value
$ALARMID = $ALARM.ExtensionData.Info.Alarm.value
Write-Host "Alarm ID is $ALARMID"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Find Host with HA Failure Alarm
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Searching for VMHost with HA Failure"
$VMHOST = Get-VMHost | Where {$_.ExtensionData.TriggeredAlarmState.Alarm.Value -eq $ALARMID}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#If Host is found with HA Failure Alarm
If($VMHOST)
{
	#Report that a VMHost was found
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "VMHost found with HA Failure is $VMHOST"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	
	#Gather Alarm info from Affected VMHost
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Getting Alarm details from $VMHOST"
	$ALARMINFO = $VMHOST.ExtensionData.TriggeredAlarmState 
	$ALARMDETAILS = $ALARMINFO | Select Alarm, Time | Where {$_.Alarm.Value -eq $ALARMID}
	$ALARMTIME = $ALARMDETAILS.Time
	Write-Host "VMHost HA Failire Occured on $ALARMTIME"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

	#Set the Time to search to the local Time Zone of the Script server running this script
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Converting Alarm details to Time Zone"$TIMEZONE" Specified"
	$ALARMTIMELOCAL = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( $ALARMTIME, $TIMEZONE)
	Write-Host "Local DateTime of VMHost HA Event is $ALARMTIMELOCAL"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	
	#Set Delay to wait for event to complete
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Adding 45 Minutes from time of incident"
	$WAITTIMEADDED = ($ALARMTIMELOCAL).AddMinutes(45)
	$CURRENTTIME = Get-Date
	$TIMESPANTOWAIT = NEW-TIMESPAN -Start $CURRENTTIME -End $WAITTIMEADDED
	$TIMESPANTOWAITMIN = $TIMESPANTOWAIT.Minutes
	$TIMESPANTOWAITSEC = $TIMESPANTOWAITMIN * 60
	Write-Host "Starting Sleep to wait for completion of event in $TIMESPANTOWAITMIN minutes, or $TIMESPANTOWAITSEC seconds"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Start-Sleep -s $TIMESPANTOWAITSEC
	Write-Host "Completed Sleep Time"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	
	#Get Cluster
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Getting Cluster of Affected VMHost $VMHOST"
	$CLUSTER = Get-VMHost $VMHOST | Get-Cluster
	Write-Host "Cluster of VMHost HA Event is $CLUSTER"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

	#Get Datacenter
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Getting Datacenter of Affected VMHost $VMHOST"
	$DATACENTER = $CLUSTER | Get-Datacenter
	$DATACENTER = $DATACENTER.Name
	Write-Host "Datacenter of VMHost HA Event is $DATACENTER"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
		
	#Get Events for VM HA Restart
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Getting List of VMs Affected by Affected VMHost $VMHOST"
	$HaVMList = Get-Cluster $CLUSTER | Get-VM | Get-VIEvent -Type Warning -Start $ALARMTIMELOCAL | where {$_.EventTypeID -eq "com.vmware.vc.ha.VmRestartedByHAEvent"} | Select ObjectName,CreatedTime,FullFormattedMessage | Sort CreatedTime
	#ORIGINAL EXAMPLE # Get-Cluster "SANCA_Compute01" | Get-VM ARW-W-020 | Get-VIEvent | where {$_.Severity -eq "warning" -and $_.FullFormattedMessage -match "vSphere HA restarted virtual machine"} | select ObjectName,Type,CreatedTime,FullFormattedMessage | FT -a 
	Write-Host "VMs Affected by VMHost HA Event include:"
	Write-Host ($HaVMList | Select ObjectName,CreatedTime | Format-Table | Out-String)
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

	#Grab time of last VM restarting
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Sorting VMs to find last Affected by Affected VMHost $VMHOST"
	$LASTINCENDENTTIME = ($HaVMList).CreatedTime | Select -Last 1
	Write-Host "Last VM Affected by VMHost HA Event concluded at $LASTINCENDENTTIME"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

	#Total Incident Time
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Calculating total Incident Time for VMHost $VMHOST"
	$TOTALTIME = NEW-TIMESPAN -Start $ALARMTIMELOCAL -End $LASTINCENDENTTIME
	$TOTALTIMEOFINCEDENT = $TOTALTIME.Minutes
	Write-Host "Total Incident time was $TOTALTIMEOFINCEDENT minutes"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

	##Disconnect from vCenter
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Disconnecting vCenter Session"
	Disconnect-VIServer $vCenter -confirm:$false
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

	##Stopping Logging
	#Note: Must stop transcriptting prior to sending email report with attached log file
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "All Processes Completed"
	Write-Host "Stopping Transcript"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Stop-Transcript
	 
	#Send Email Report
	IF ($smtpServer){
	Write-Host "SMTP Server $SMTPSERVER Configured. Attempting to send email"
	$att = new-object Net.Mail.Attachment($LOGFILE)
	$STARTTIMESW.STOP()
	$CompletionTime = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
	$msg = new-object Net.Mail.MailMessage
	$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
	$msg.From = $MSGFROM
	$msg.To.Add($MSGTO)
	$msg.Subject = "Critical Incident Notification: ESXi VMHost Crash"
	$BodyLine1 = "Subject: Critical Incident Notification: ESXi VMHost Crash"
	$BodyLine2 = "-  Issue description? ESXi host $VMHost in cluster $CLUSTER in datacenter $DATACENTER on VCSA $vCenter" 
	$BodyLine3 = "-  Day/Time of occurrence? $ALARMTIMELOCAL (based on TimeZone $TIMEZONE)"
	$BodyLine4 = "-  How did we become aware of the situation? vCenter email alerting."
	$BodyLine5 = "-  Duration of outage? $TOTALTIMEOFINCEDENT minutes"
	$BodyLine6 = "-  If not resolved - estimated time until it is resolved? N/A"
	$BodyLine7 = "-  Impacted customers? $DATACENTER virtual machines listed below"
	$BodyLine8 = "-  How are the customers impacted? Access to the listed virtual machines would be unsuccessful."
	$BodyLine9 = "-  Communication made to impacted customers? "
	$BodyLine10 = "-  Who / what teams / vendors are working on it? INFR"
	$BodyLine11 = "-  What was the resolution? vCenter HA restarted virtual machines on other hosts in the cluster."
	$BodyLine12 = "-  Is a Root Cause Analysis being worked on, and who is accountable / responsible for completing it? Virtualization Team will working with the Hardware vendor and VMware"
	$BodyLine13 = "-  List of impacted VMs: "
	$BodyLine14 = ($HaVMList | Select ObjectName | Sort ObjectName  | Format-Table -HideTableHeaders | Out-String)
	$BodyLine15 = "Total Script Time: " + $STARTTIMESW.Elapsed.TotalMinutes + " Minutes"

	$msg.Body = "
	$BodyLine1 `n
	$BodyLine2 `n
	$BodyLine3 `n
	$BodyLine4 `n
	$BodyLine5 `n
	$BodyLine6 `n
	$BodyLine7 `n
	$BodyLine8 `n
	$BodyLine9 `n
	$BodyLine10 `n
	$BodyLine11 `n
	$BodyLine12 `n
	$BodyLine13 `n
	$BodyLine14 `n
	$BodyLine15 `n
	"
	Write-Output $msg.Body
	$msg.Attachments.Add($att) 
	$smtp.Send($msg)
	}
	Else{
	$Subject = "Critical Incident Notification: ESXi VMHost Crash "
	$BodyLine1 = "Subject: Critical Incident Notification: ESXi VMHost Crash"
	$BodyLine2 = "-  Issue description? ESXi host $VMHost in cluster $CLUSTER in datacenter $DATACENTER on VCSA $vCenter" 
	$BodyLine3 = "-  Day/Time of occurrence? $ALARMTIMELOCAL (based on TimeZone $TIMEZONE)"
	$BodyLine4 = "-  How did we become aware of the situation? vCenter email alerting."
	$BodyLine5 = "-  Duration of outage? $TOTALTIMEOFINCEDENT minutes"
	$BodyLine6 = "-  If not resolved - estimated time until it is resolved? N/A"
	$BodyLine7 = "-  Impacted customers? $DATACENTER virtual machines listed below"
	$BodyLine8 = "-  How are the customers impacted? Access to the listed virtual machines would be unsuccessful."
	$BodyLine9 = "-  Communication made to impacted customers? Communications will be made by CSHB"
	$BodyLine10 = "-  Who / what teams / vendors are working on it? INFR"
	$BodyLine11 = "-  What was the resolution? vCenter HA restarted virtual machines on other hosts in the cluster."
	$BodyLine12 = "-  Is an RCA/CAP being worked on, and who is accountable / responsible for completing it? INFR working with HPE and VMware"
	$BodyLine13 = "-  List of impacted VMs: "
	$BodyLine14 = ($HaVMList | Select ObjectName | Sort ObjectName | Format-Table -HideTableHeaders | Out-String)
	$BodyLine15 = "Total Script Time: " + $STARTTIMESW.Elapsed.TotalMinutes + " Minutes"

	Write-Host $Subject
	Write-Host $BodyLine1
	Write-Host $BodyLine2
	Write-Host $BodyLine3
	Write-Host $BodyLine4
	Write-Host $BodyLine5
	Write-Host $BodyLine6
	Write-Host $BodyLine7
	Write-Host $BodyLine8
	Write-Host $BodyLine9
	Write-Host $BodyLine10
	Write-Host $BodyLine11
	Write-Host $BodyLine12
	Write-Host $BodyLine13
	Write-Host $BodyLine14
	Write-Host $BodyLine15
	}

}
Else
{
	#No VMHost Found with HA Failure
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "No VMHost found with HA Failure Issues"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	
	##Disconnect from vCenter
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Disconnecting vCenter Session"
	Disconnect-VIServer $vCenter -confirm:$false
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
	#Note: Must stop transcriptting prior to sending email report with attached log file
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "All Processes Completed"
	Write-Host "Stopping Transcript"
	Stop-Transcript
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
}

Write-Host "Script Completed"
