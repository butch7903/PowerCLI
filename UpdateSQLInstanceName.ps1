##Setup Logging
##Setup Logging
$TaskName = "UpdateSQLInstanceName"
##Get Current Path
$pwd = pwd
##Get Date Info for naming of Log File variable
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $TaskName + "_" + $LOGDATE + ".txt"
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

##Starting Logging
Start-Transcript -path $LOGFILE -Append

#Verify SQL Service has started before proceeding to next steps
DO 
{
	$Status  = Get-Service MSSQLSERVER | Select Status
	$Status = $Status.Status
	Write-Host "SQL Service Status is" $Status
	Start-Sleep -Seconds 2
} until ($Status -eq "Running")
Write-Host "SQL Service Running"

##Load SQL PowerShell Module
import-module sqlps -disablenamechecking
CD C:

$CurrentSQLName = invoke-sqlcmd -Query "SELECT @@SERVERNAME AS 'Server Name';"
CD C:
$CurrentSQLName = $CurrentSQLName."Server Name"
Write-Host "Current SQL Server Name is" $CurrentSQLName
$ComputerName = $env:computername
Write-Host "Computer Name is" $ComputerName
If ($CurrentSQLName -ne $ComputerName){

##Update SQL instance to Server Name
Write-Host "Running SQL Commands to reset SQL Instance to Current Server Name"
Invoke-sqlcmd -Query "sp_dropserver $CurrentSQLName;"
CD C:
Invoke-sqlcmd -Query "sp_addserver $ComputerName, local;"
CD C:

##Update IP Address for SQL instance
#Reference https://sqlserverpowershell.com/2016/07/07/change-sql-server-configuration-manager-ip-address/
$ipV4 = Test-Connection -ComputerName (hostname) -Count 1  | Select IPV4Address
$ipV4 = $ipV4.IPV4Address
$ipV4 = [string]$ipV4
Write-Host "IP of server is" $ipV4
$ComputerName = $env:computername
$Instance = "mssqlserver"
$urn = "ManagedComputer[@Name='$ComputerName']/ServerInstance[@Name='$Instance']/ServerProtocol[@Name='Tcp']"
$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $ComputerName
$tcp = $wmi.GetSmoObject($urn);
$tcp.IPAddresses["IP1"].IPAddressProperties["IpAddress"].Value = $ipV4;
$tcp.Alter();

##Restart Service https://technet.microsoft.com/en-us/library/ee176942.aspx
Write-Host "Restarting SQL Services"
Restart-Service MSSQLSERVER -Force
Start-Sleep -Seconds 10

##Verify SQL Instance is Renamed
Write-Host "Checking to see if Server Name is updated"
$NewSQLName = invoke-sqlcmd -Query "SELECT @@SERVERNAME AS 'Server Name';" 
CD C:
$NewSQLName = $NewSQLName."Server Name"
Write-Host "New SQL Server Name is now" $NewSQLName
Write-Host "IP of SQL Instance is now set to" $tcp.IPAddresses["IP1"].IPAddressProperties["IpAddress"].Value
}
Else 
{
#Check IP to verify it is the correct one
$ipV4 = Test-Connection -ComputerName (hostname) -Count 1  | Select IPV4Address
$ipV4 = $ipV4.IPV4Address
$ipV4 = [string]$ipV4
Write-Host "IP of server is" $ipV4
$ComputerName = $env:computername
$Instance = "mssqlserver"
$urn = "ManagedComputer[@Name='$ComputerName']/ServerInstance[@Name='$Instance']/ServerProtocol[@Name='Tcp']"
$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $ComputerName
$tcp = $wmi.GetSmoObject($urn);
$SQLIP = $tcp.IPAddresses["IP1"].IPAddressProperties["IpAddress"].Value
Write-Host "SQL IP Currently is" $SQLIP

If($SQLIP -ne $ipV4)
{
$ipV4 = Test-Connection -ComputerName (hostname) -Count 1  | Select IPV4Address
$ipV4 = $ipV4.IPV4Address
Write-Host "IP of server is" $ipV4
$ComputerName = $env:computername
$Instance = "mssqlserver"
$urn = "ManagedComputer[@Name='$ComputerName']/ServerInstance[@Name='$Instance']/ServerProtocol[@Name='Tcp']"
$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $ComputerName
$tcp = $wmi.GetSmoObject($urn);
$tcp.IPAddresses["IP1"].IPAddressProperties["IpAddress"].Value = [string]$ipV4;
$tcp.Alter();

##Restart Service https://technet.microsoft.com/en-us/library/ee176942.aspx
Write-Host "Restarting SQL Services"
Restart-Service MSSQLSERVER -Force
Start-Sleep -Seconds 10
}
}

##Stopping Logging
Stop-Transcript
