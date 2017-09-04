IF ($PSVersionTable.PSVersion.Major -lt 5)
	{
		Write-Host "PowerShell is less than version 5. '
		Please download and install updated Windows Management Framework (PowerShell)'
		from the below web link and then rerun this script'
		https://www.microsoft.com/en-us/download/details.aspx?id=54616
		"
		Start-Process -FilePath "https://www.microsoft.com/en-us/download/details.aspx?id=54616"
		Read-Host 'Press Enter to continue…' | Out-Null
		Exit
	} ELSE
	{
		Write-Host "PowerShell version 5 or higher has been found'
		Continueing to Install VMware PowerCLI..."
	}

Write-Host "Uninstall any old versions of the PowerCLI Installer"
$data = get-wmiobject -class win32_product -filter "Name LIKE '%VMware PowerCLI%'"
$UninstallString = $data.IdentifyingNumber
$UninstallCommand = "MSIEXEC /X" + $UninstallString + " /norestart /passive"
cmd.exe /c $UninstallCommand

Write-Host "Uninstalling any versions of PowerCLI that is currently installed via Powershell"
$Module = Get-Module VMware.PowerCLI -ListAvailable
Remove-Module $Module.Name
Remove-Item $Module.ModuleBase -Recurse -Force

Write-Host "Verify that no PowerCLI versions return any data after this command"
Get-Module VMware.PowerCLI -ListAvailable

#Write-Host "Hit any key to continue, or Ctrl-C to exit"
#$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host "Setting Micrsoft PowerShell Gallery as a Trusted Repository"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted 

Write-Host "Verifying that NuGet is at minimum version 2.8.5.201 to proceed with update"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false

Write-Host "Installing New version of PowerCLI"
Install-Module -Name VMware.PowerCLI -Scope AllUsers -Force -AllowClobber

Write-Host "Verify version of newly installed PowerCLI"
Get-Module VMware.PowerCLI -ListAvailable | Select Name, Version

Write-Host "Verify subversions of newly installed PowerCLI"
Get-Module VMware.* -ListAvailable | Select Name, Version

Write-Host "Creating a Desktop shortcut to the VMware PowerCLI Module"
$AppLocation = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$Arguments = '-noe -c "Import-Module VMware.PowerCLI"'
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:Public\Desktop\VMware PowerCLI.lnk")
$Shortcut.TargetPath = $AppLocation
$Shortcut.Arguments = $Arguments
$ShortCut.Hotkey = "CTRL+SHIFT+V"
$Shortcut.IconLocation = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe,1"
$Shortcut.Description ="Launch VMware PowerCLI"
$Shortcut.WorkingDirectory ="C:\"
$Shortcut.Save()

Write-Host "ShortCut Created"
Write-Host "You may use the CTRL+SHIFT+V method to open VMware PowerCLI"

Write-Host "Loading Module PowerCLI to use"
Import-Module VMware.PowerCLI

Write-Host "Look at the PowerCLI Help Guide"
Get-PowerCLIHelp

Write-Host "List PowerCLI Version"
Get-Module VMware.PowerCLI -ListAvailable | Select Name,Version

