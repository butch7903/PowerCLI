<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			January 20,2026
	Version:		3.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script automates the export of VMware information via RVTools

	.DESCRIPTION
		Use this script to document VCSA Configuration

	.NOTES
		This script requires RVTools be installed on the local machine
		
	.EXAMPLE
	#Example - Interactive
	$VCSA = "hamvc01.hamker.local"
	./export-rvtools-automation.ps1 -VCSA $VCSA
	
	.EXAMPLE
	#Example - Full Automation with no confirmation at end of script
	$VCSA = "hamvc01.hamker.local"
	$Confirm = $false
	./export-rvtools-automation.ps1 -VCSA $VCSA -Confirm $Confirm
#>
param(

		[Parameter(Mandatory=$true)][string]$VCSA,
		[Parameter(Mandatory=$false)][boolean]$Confirm
)

#Set Confirm default to true
If($Confirm.Count -eq 0 -Or !$Confirm){
	$Confirm = $true
}

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()
Write-Host "Start Time $STARTTIME"

##Set Variables
##Get Current Path
$LOCATION = Get-Location

#Test if monthstokeep.txt file exists
$MonthsToKeepFile = "monthstokeep.txt"
$MonthsToKeepLocation = $LOCATION.path + '/' + $MonthsToKeepFile
If((Test-Path -Path $MonthsToKeepLocation) -eq $true){
	Write-Host "Months to Keep File found. Importing"
	$Monthsback = Get-Content $MonthsToKeepLocation
}Else{
	$MONTHSTOKEEP = Read-Host "Please Input the Number of Months you wish to keep your Data
Example: -6 for 6 months"
	Write-Host "Months to keep is $($MONTHSTOKEEP)"
	Write-Host "Press any key to continue or CTRL-C to cancel"
	PAUSE
	#Export data to file
	Write-Host "Creating monthstokeep.txt"
	$MONTHSTOKEEP | Out-File -FilePath $MonthsToKeepLocation
	#Import data from file
	$Monthsback = Get-Content $MonthsToKeepLocation
}
	

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $LOCATION.path+"\log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}
Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $LOCATION.path+"\log\"+$LOGFILENAME

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
Write-Host "Attempting to remove Log files older than 5 days"
$Daysback = "-5"
$CurrentDateRemoval = Get-Date
$DatetoDelete = $CurrentDateRemoval.AddDays($Daysback)
Get-ChildItem $LogFolder| Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item -Confirm:$false
Write-Host "Completed attempting to remove Log files older than 5 days"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Export Folder
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating Export Folder and Variables"
##Specify Export File Info
$EXPORTFILENAME = (Get-Date -Format "M-d-yyyy_HH-mm") + "_" + $VCSA + "_RVTools_export.xlsx"
#Create Export Folder
$EXPORTFOLDER = $LOCATION.path+"\export"
If (Test-Path $EXPORTFOLDER){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $EXPORTFOLDER -type directory
}
$EXPORTFOLDERVCSA = $LOCATION.path+"\export\$VCSA"
If (Test-Path $EXPORTFOLDERVCSA){
	Write-Host "Export VCSA Directory Created - $($VCSA). Continuing..."
}Else{
	New-Item $EXPORTFOLDERVCSA -type directory
}
#Specify Log File
#$EXPORTFILE = $LOCATION.path+"\Export\"+$EXPORTFILENAME
Write-Host "Completed creating Export Folder and Variables"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Standard Variables
#Test if Dell Version or old version
If((Test-Path -Path "C:\Program Files (x86)\Dell\RVTools\RVTools.exe") -eq $true){
	#Dell Path
	$RVTOOLSEXE = "C:\Program Files (x86)\Dell\RVTools\RVTools.exe" #Folder path to rvtools.exe
	$VERSIONTYPE = 'Dell'
}Else{
	$RVTOOLSEXE = "c:\program files (x86)\robware\rvtools\rvtools.exe"
	$VERSIONTYPE = 'Original'
}
#$DATE = Get-Date -format "MM-dd-yyyy_HH-mm"
$CURRENTDATE = Get-Date
#$FILENAME = "RVTools_export_"+"$VCSA"+"_"+$DATE+".xlsx"

##Check for VCSA Parameter
If(!$VCSA){
 Write-Error "No VCSA Specified"
}
IF($VCSA){
	Write-Host "VCSA Specified in Parameter is $VCSA"
}

##Create Secure AES Keys for User and Password Management
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
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
	$exportObject = New-Object psobject -Property @{
		UserName = $newPScreds.UserName
		Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
	}
	$exportObject | Export-Clixml ($VCSA +".xml")
	$MyCredential = $newPScreds
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Clean up Old RVTools Files Prior to Starting
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Attempting Cleanup of Old RVTools Exports $($Monthsback) Months"
$DatetoDelete = $CurrentDate.AddMonths($Monthsback)
Get-ChildItem $EXPORTFOLDERVCSA -Recurse -Filter *.xlsx | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item -Confirm:$false
Write-Host "Completed Cleanup of Old RVTools Exports"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Set VCSA Access Creds to Variables
$VCSAUSER = $MyCredential.UserName
$VCSASecurePassword = $MyCredential.Password

##Create RVTools Start Process Expression
#Export CMD Commands
#rvtools.exe -s %$VCServer% -u %username% -p %password% -c ExportAll2xlsx -d %$AttachmentDir% -f %$AttachmentFile%
#Original Method
If($VERSIONTYPE -eq 'Original'){
	$VCSAUnsecurePassword = (New-Object PSCredential "user",$VCSASecurePassword).GetNetworkCredential().Password
	$RVTOOLSCOMMAND = "Start-Process -FilePath '$RVTOOLSEXE' -ArgumentList '-s $VCSA -u $VCSAUSER -p $VCSAUnsecurePassword -c ExportAll2xlsx -d $EXPORTFOLDERVCSA -f $EXPORTFILENAME' -Wait"
}
#Dell RVTools Method
If($VERSIONTYPE -eq 'Dell'){
	# Encrypt password for Dell RVTools
	$encryptedpwd = $VCSASecurePassword | ConvertFrom-SecureString
	# Prefix the encrypted password with the string "_RVToolsV3PWD" so that RVTools understands what needs to be done
	$encryptedpwd = '_RVToolsV3PWD' + $encryptedpwd
	#Document Command for RVTools Export
	$RVTOOLSCOMMAND = "Start-Process -FilePath '$RVTOOLSEXE' -ArgumentList '-s $VCSA -u $VCSAUSER -p $encryptedpwd -c ExportAll2xlsx -d $EXPORTFOLDERVCSA -f $EXPORTFILENAME' -Wait"
}

#Run RVTools Expression
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Starting RVTools Capture for VCSA $VCSA"
Invoke-Expression $RVTOOLSCOMMAND
Write-Host "Completed RVTools Capture for VCSA $VCSA"
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
Write-Host "Script Completed for $VCSA"
If($Confirm -eq $true){
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
