<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			January 7,2021
	Version:		2.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script automates the export of VMware information via RVTools

	.DESCRIPTION
		Use this script to document VCSA Configuration

	.NOTES
		This script requires RVTools be installed on the local machine

	.TROUBLESHOOTING
		
#>

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

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
	$VCSA = $Line.VCSA
	Write-Host "vCenter specified in file is:"$VCSA
	$MONTHSTOKEEP = $Line.MonthsToKeep
	Write-Host "Months to Keep RVTools Exports:"$MONTHSTOKEEP
	
	Write-Host "Continuing..."
	Start-Sleep -Seconds 2
}
}
Else {
$Answers_List = @()
$Answers="" | Select Version,SubVersion,VCSA,MonthsToKeep
Write-Host "Answer file NOT found. Please input information to continue."
$Version = "2"
$Answers.Version = $Version
$SubVersion = "0"
$Answers.SubVersion = $SubVersion
$VCSA = Read-Host "Please input the FQDN or IP of your VCSA
Example: hamvc01.hamker.local
"
$Answers.VCSA = $VCSA
$MONTHSTOKEEP = Read-Host "Please Input the Number of Months you wish to keep your Data
Example: -6 for 6 months"
$Answers.MonthsToKeep = $MONTHSTOKEEP
$Answers_List += $Answers
$Answers_List | Format-Table -AutoSize
Write-Host "Exporting Information to File"$AnswerFile
$Answers_List | Export-CSV -NoTypeInformation $AnswerFile
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

##################################Start of Script#########################################################

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

##Export Folder
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating Export Folder and Variables"
##Specify Export File Info
$EXPORTFILENAME = "RVTools_export_"+"$VCSA"+"_"+$LOGDATE+".xlsx"
#Create Export Folder
$EXPORTFOLDER = $pwd.path+"\Export"
If (Test-Path $EXPORTFOLDER){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $EXPORTFOLDER -type directory
}
#Specify Log File
$EXPORTFILE = $pwd.path+"\Export\"+$EXPORTFILENAME
Write-Host "Completed creating Export Folder and Variables"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Standard Variables
$RVTOOLSEXE = "c:\program files (x86)\robware\rvtools\rvtools.exe" #Folder path to rvtools.exe
$DATE = Get-Date -format "MM-dd-yyyy_HH-mm"
$CURRENTDATE = Get-Date
$FILENAME = "RVTools_export_"+"$VCSA"+"_"+$DATE+".xlsx"

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

##Clean up Old RVTools Files Prior to Starting
Write-Host "Deleting Old RVTools Exports"
$DatetoDelete = $CurrentDate.AddMonths($MONTHSTOKEEP)
Get-ChildItem $ExportFolder -Filter *.xlsx | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item -Confirm:$false
Write-Host "Completed deleting Old RVTools Exports"

##Set VCSA Access Creds to Variables
$VCSAUSER = $MyCredential.UserName
$VCSASecurePassword = $MyCredential.Password
$VCSAUnsecurePassword = (New-Object PSCredential "user",$VCSASecurePassword).GetNetworkCredential().Password

##Create RVTools Start Process Expression
#Export CMD Commands
#rvtools.exe -s %$VCServer% -u %username% -p %password% -c ExportAll2xlsx -d %$AttachmentDir% -f %$AttachmentFile%
$RVTOOLSCOMMAND = "Start-Process -FilePath '$RVTOOLSEXE' -ArgumentList '-s $VCSA -u $VCSAUSER -p $VCSAUnsecurePassword -c ExportAll2xlsx -d $EXPORTFOLDER -f $EXPORTFILENAME' -Wait"
#Run RVTools Expression
Write-Host "Starting RVTools Capture for VCSA $VCSA"
Invoke-Expression $RVTOOLSCOMMAND
Write-Host "Completed RVTools Capture for VCSA $VCSA"

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
Write-Host "Script Completed for $VCSA"
#Comment out the next 2 lines if you are setting this up to be fully automated.
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
