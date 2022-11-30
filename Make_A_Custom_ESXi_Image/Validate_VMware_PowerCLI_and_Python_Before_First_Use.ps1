<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			November 30,2022
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will validate that you have VMware PowerCLI and Python Installed Correctly.

	.DESCRIPTION
		Use this script to validate PowerCLI/Python prior to first Use.	

	.NOTES
	Based on 
	https://vdc-repo.vmware.com/vmwb-repository/dcr-public/9619cb6d-3975-4bff-aa1f-0e785283a1a9/58d0925b-e15d-4803-bbd4-eb314dd165b0/GUID-9081EBAF-BF85-48B1-82A0-D1C49F3FF1E8.html
	
	11-30-2023 Initial Build
#>

##Set PowerShell Window Settings
$pshost = get-host
$pswindow = $pshost.ui.rawui
$pswindow.windowtitle = "Validating PowerCLI and Python Configurations Before First Use of Image Builder"

##Get Current Path
$pwd = pwd

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + "Validation_Script_" + $LOGDATE + ".txt"
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

##Check if Modules are installed, if so load them, else install them
if (Get-InstalledModule -Name VMware.PowerCLI -MinimumVersion 11.4) {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module VMware PowerCLI required minimum version was found previously installed"
	Write-Host "Importing PowerShell Module VMware PowerCLI"
	Import-Module -Name VMware.PowerCLI
	Write-Host "Importing PowerShell Module VMware PowerCLI Completed"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	CLEAR
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
	Clear
}

Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host "Validating VMware PowerCLI Version and Python Pre-Reqs"
$POWERCLIVER = Get-InstalledModule VMware.PowerCLI | Select Name, Version
If($POWERCLIVER.Version -gt 12.9)
{
	Write-Host "VMware PowerCLI Version Greater than 12.9 Detected..."
	Write-Host "Validating Python is Configured Correctly..."
	$PYPATH = Get-PowerCLIConfiguration | Select Scope,PythonPath | Where {$_.Scope -eq 'User'}
	If(!$PYPATH.PythonPath)
	{
		Write-Host "Python Path Not Set" -ForegroundColor Red
		Write-Host "Please follow VMware Documentation to install Python and configure the PythonPath Setting" -ForegroundColor Yellow
		Write-Host "https://developer.vmware.com/docs/15315/powercli-user-s-guide/GUID-9081EBAF-BF85-48B1-82A0-D1C49F3FF1E8.html" -ForegroundColor Yellow
		Write-Host "https://blogs.vmware.com/PowerCLI/2022/11/powercli-13-is-now-ga.html" -ForegroundColor Yellow
	}
	If ($IsWindows -or $ENV:OS)
	{
		Write-Host "Windows OS Detected..."
		If($PYPATH.PythonPath -notlike "*python.exe")
		{
			Write-Host "PythonPath is not correctly set..." -ForegroundColor Red
			Write-Host "Please follow VMware Article to properly Install Python and set PythonPath" -ForegroundColor Red
			Write-Host "Path should be similar to C:\Program Files\Python\python.exe" -ForegroundColor Green
			Write-Host "Command to set path is like below. Please run this with administrative Powershell rights to set for AllUsers" -ForegroundColor Green
			Write-Host "Set-PowerCLIConfiguration -PythonPath "C:\Program Files\Python\python.exe" -Scope AllUsers -Confirm:$false" -ForegroundColor Green
			Write-Host "Set-PowerCLIConfiguration -PythonPath "C:\Program Files\Python\python.exe" -Scope User -Confirm:$false" -ForegroundColor Green
			Write-Host "https://vdc-repo.vmware.com/vmwb-repository/dcr-public/9619cb6d-3975-4bff-aa1f-0e785283a1a9/58d0925b-e15d-4803-bbd4-eb314dd165b0/GUID-EB16871E-D52B-4B46-9675-241AD42C1BE6.html" -ForegroundColor Yellow
			Write-Host "https://blogs.vmware.com/PowerCLI/2022/11/powercli-13-is-now-ga.html" -ForegroundColor Yellow
			PAUSE
			EXIT
		}Else{
			$PATHTEST = Test-Path $PYPATH.PythonPath
			If($PATHTEST -eq $true)
			{
				Write-Host "VMware PowerCLI Python Path is set to: $($PYPATH.PythonPath)" -ForegroundColor Green
				Write-Host "File Path has Tested True" -ForegroundColor Green
				Write-Host "VMware PowerCLI PythonPath was previously set successfully, continuing..." -ForegroundColor Green
			}Else{
				Write-Host "PythonPath is set, but not properly installed" -ForegroundColor Red
				Write-Host "Please Install Python per VMware Documentation:" -ForegroundColor Yellow
				Write-Host "https://vdc-repo.vmware.com/vmwb-repository/dcr-public/9619cb6d-3975-4bff-aa1f-0e785283a1a9/58d0925b-e15d-4803-bbd4-eb314dd165b0/GUID-9081EBAF-BF85-48B1-82A0-D1C49F3FF1E8.html#GUID-9081EBAF-BF85-48B1-82A0-D1C49F3FF1E8"  -ForegroundColor Yellow
				PAUSE
				EXIT
			}
		}
	}ElseIf ($IsLinux -or $ENV:OS)
	{
		Write-Host "Linux OS Detected..."
		If($PYPATH.PythonPath -notlike "/usr/bin/python3*")
		{
			Write-Host "PythonPath is not correctly set..." -ForegroundColor Red
			Write-Host "Please follow VMware Article to properly Install Python and set PythonPath" -ForegroundColor Red
			Write-Host "Follow commands to install Python:" -ForegroundColor Yellow
			Write-Host "sudo apt-get install -y python3" -ForegroundColor Yellow
			Write-Host "sudo apt-get install -y pip" -ForegroundColor Yellow
			Write-Host "pip install six psutil lxml pyopenssl" -ForegroundColor Yellow
			Write-Host "Path should be similar to /usr/bin/python3" -ForegroundColor Green
			Write-Host "Command to set path is like below. Please run this with administrative Powershell rights to set for AllUsers" -ForegroundColor Green
			Write-Host "Set-PowerCLIConfiguration -PythonPath "/usr/bin/python3" -Scope AllUsers -Confirm:$false" -ForegroundColor Green
			Write-Host "Set-PowerCLIConfiguration -PythonPath "/usr/bin/python3" -Scope User -Confirm:$false" -ForegroundColor Green
			Write-Host "https://vdc-repo.vmware.com/vmwb-repository/dcr-public/9619cb6d-3975-4bff-aa1f-0e785283a1a9/58d0925b-e15d-4803-bbd4-eb314dd165b0/GUID-101A5D2A-6BEB-43B0-8328-3B2F9F80C628.html" -ForegroundColor Yellow
			Write-Host "https://blogs.vmware.com/PowerCLI/2022/11/powercli-13-is-now-ga.html" -ForegroundColor Yellow
			PAUSE
			EXIT
		}Else{
			$PATHTEST = Test-Path $PYPATH.PythonPath
			If($PATHTEST -eq $true)
			{
				Write-Host "VMware PowerCLI Python Path is set to: $($PYPATH.PythonPath)" -ForegroundColor Green
				Write-Host "File Path has Tested True" -ForegroundColor Green
				Write-Host "VMware PowerCLI PythonPath was previously set successfully, continuing..." -ForegroundColor Green
			}Else{
				Write-Host "PythonPath is set, but not properly installed" -ForegroundColor Red
				Write-Host "Please Install Python per VMware Documentation:" -ForegroundColor Yellow
				Write-Host "https://vdc-repo.vmware.com/vmwb-repository/dcr-public/9619cb6d-3975-4bff-aa1f-0e785283a1a9/58d0925b-e15d-4803-bbd4-eb314dd165b0/GUID-9081EBAF-BF85-48B1-82A0-D1C49F3FF1E8.html#GUID-9081EBAF-BF85-48B1-82A0-D1C49F3FF1E8"  -ForegroundColor Yellow
				PAUSE
				EXIT
			}
		}
	}ElseIf ($IsMacOS -or $ENV:OS)
	{
		Write-Host "macOS Detected..."
		If($PYPATH.PythonPath -notlike "/usr/bin/python3*")
		{
			Write-Host "PythonPath is not correctly set..." -ForegroundColor Red
			Write-Host "Please follow VMware Article to properly set PythonPath" -ForegroundColor Red
			Write-Host "Path should be similar to /usr/bin/python3" -ForegroundColor Yellow
			Write-Host "Command to set path is like below. Please run this with administrative Powershell rights to set for AllUsers" -ForegroundColor Green
			Write-Host "Set-PowerCLIConfiguration -PythonPath "/usr/bin/python3" -Scope AllUsers -Confirm:$false" -ForegroundColor Green
			Write-Host "Set-PowerCLIConfiguration -PythonPath "/usr/bin/python3" -Scope User -Confirm:$false" -ForegroundColor Green
			Write-Host "https://vdc-repo.vmware.com/vmwb-repository/dcr-public/9619cb6d-3975-4bff-aa1f-0e785283a1a9/58d0925b-e15d-4803-bbd4-eb314dd165b0/GUID-F0405EDE-45CE-4DE4-A52A-5C458B984392.html" -ForegroundColor Yellow
			Write-Host "https://blogs.vmware.com/PowerCLI/2022/11/powercli-13-is-now-ga.html" -ForegroundColor Yellow
			PAUSE
			EXIT
		}Else{
			$PATHTEST = Test-Path $PYPATH.PythonPath
			If($PATHTEST -eq $true)
			{
				Write-Host "VMware PowerCLI Python Path is set to: $($PYPATH.PythonPath)" -ForegroundColor Green
				Write-Host "File Path has Tested True" -ForegroundColor Green
				Write-Host "VMware PowerCLI PythonPath was previously set successfully, continuing..." -ForegroundColor Green
			}Else{
				Write-Host "PythonPath is set, but not properly installed" -ForegroundColor Red
				Write-Host "Please Install Python per VMware Documentation:" -ForegroundColor Yellow
				Write-Host "https://vdc-repo.vmware.com/vmwb-repository/dcr-public/9619cb6d-3975-4bff-aa1f-0e785283a1a9/58d0925b-e15d-4803-bbd4-eb314dd165b0/GUID-9081EBAF-BF85-48B1-82A0-D1C49F3FF1E8.html#GUID-9081EBAF-BF85-48B1-82A0-D1C49F3FF1E8"  -ForegroundColor Yellow
				PAUSE
				EXIT
			}
		}
	}
}
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
Write-Host "Script Validation Completed"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
