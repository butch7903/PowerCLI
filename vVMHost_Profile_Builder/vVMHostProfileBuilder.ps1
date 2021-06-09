<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			June 9, 2021
	Version:		1.3.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will generate a Host Profile from a Host, modify it to disconnect 
		physical storage and PCI configuration, set specific site settings for SysLog,
		NTP, DNS, enforce setting Services to specific settings, and add SATP Claimrules.

	.DESCRIPTION
		Use this script to create a Host profile for a Cluster of VMHosts. The only
		change this script makes to a host itself is to enable the CIM Service on a VMhost
		configuration prior to configuring the Host Profile for optimal config. After
		the script completes it will apply the Host Profile to the cluster.
	.NOTES
		This script requires a VMware PowerCLI minimum version 11.4 or greater. 
		
		This script takes into account that you have already configured a VMHost with 
		the proper networking configuration prior to generating the Host Profile from 
		it.

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

##Adding Function needed for manipulating Host Profiles
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

##Set PowerShell Window Settings
$pshost = get-host
$pswindow = $pshost.ui.rawui
$newsize = $pswindow.buffersize
$newsize.height = 30000
$newsize.width = 130
$pswindow.buffersize = $newsize
$newsize = $pswindow.windowsize
$newsize.height = (get-host).UI.RawUI.MaxWindowSize.Height
$newsize.width = 130
$pswindow.windowtitle = "vVMHostProfileBuilder"
$pswindow.windowsize = $newsize

##Maximize Current PowerShell Window
function Show-Process($Process, [Switch]$Maximize)
{
<#
	.NOTES
	Reference http://community.idera.com/powershell/powertips/b/tips/posts/bringing-window-in-the-foreground
#>
  $sig = '
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern int SetForegroundWindow(IntPtr hwnd);
  '
  
  if ($Maximize) { $Mode = 3 } else { $Mode = 4 }
  $type = Add-Type -MemberDefinition $sig -Name WindowAPI -PassThru
  $hwnd = $process.MainWindowHandle
  $null = $type::ShowWindowAsync($hwnd, $Mode)
  $null = $type::SetForegroundWindow($hwnd) 
}
Show-Process -Process (Get-Process -id $pid) -Maximize

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$pwd = pwd

#Create Export Folder
$CONFIGFOLDER = $pwd.path+"\Config"
If (Test-Path $CONFIGFOLDER){
	Write-Host "Config Directory Created. Continuing..."
}Else{
	New-Item $CONFIGFOLDER -type directory
}

#Create Export Folder
$CREDSFOLDER = $pwd.path+"\Creds"
If (Test-Path $CREDSFOLDER){
	Write-Host "Config Directory Created. Continuing..."
}Else{
	New-Item $CREDSFOLDER -type directory
}

##Import Site File or Create 1
$SITECSVFILENAME = "SITEList.csv"
$SITECSVFILEGET = Get-Item "$CONFIGFOLDER\$SITECSVFILENAME" -ErrorAction SilentlyContinue
$SITECSVFILE = "$CONFIGFOLDER\$SITECSVFILENAME"
$SITENAMELIST = @()
If(!$SITECSVFILEGET)
{
	CLS
	Write-Host "Site List CSV File not found"
	$SITENAME = @()
	$CREATENEWRECORD = "" | Select Site
	$CREATENEWRECORD.Site = "Create New Record" 
	$SITENAME += $CREATENEWRECORD
	$SITETEMPLIST = "" | Select Site
	$SITETEMPLIST.Site = Read-Host "Please provide a Site Name
	Note: Do nost use the letters NA for this"
	$SITENAME += $SITETEMPLIST
	$SITENAMELIST = $SITENAME
	$SITENAME | Export-CSV -NoTypeInformation -PATH $SITECSVFILE
	$SITE = $SITETEMPLIST.Site
	Write-Host "Site Selected is $SITE"
}
If($SITECSVFILEGET)
{
	CLS
	Write-Host "Site List CSV File found. Importing file..."
	$IMPORTSITELIST = Import-CSV -PATH $SITECSVFILE
	$countCL = 0  
	foreach($oC in $IMPORTSITELIST)
	{   
		$NAME = $oC.Site
		Write-Output "[$countCL] $NAME" 
		$countCL = $countCL+1  
	}
	Write-Host " "  
	$choice = $null
	$choice = Read-Host "At Which Site do you wish to Work with Host Profiles"
	$CHOICEPICKED = ($IMPORTSITELIST[$choice]).Site
	If($CHOICEPICKED -eq "Create New Record")
	{
		$SITENAME = $IMPORTSITELIST
		Write-Host "Creating New Record Selected..."
		$SITETEMPLIST = "" | Select Site
		$SITETEMPLIST.Site = Read-Host "Please provide a Site Name"
		$SITENAME += $SITETEMPLIST
		$SITENAME | Export-CSV -NoTypeInformation -PATH $SITECSVFILE -Confirm:$false
		$SITENAMELIST = $SITENAME
		$SITE = $SITETEMPLIST.Site
		Write-Host "Site Selected is $SITE"
	}Else{
		$SITE = $CHOICEPICKED
		Write-Host "Site Selected is $SITE"
		$SITENAMELIST = $IMPORTSITELIST
	}
}

##Select VCSA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import VCSA File or Create 1
$VCSACSVFILENAME = "VCSAlist.csv"
$VCSACSVFILEGET = Get-Item "$CONFIGFOLDER\$VCSACSVFILENAME" -ErrorAction SilentlyContinue
$VCSACSVFILE = "$CONFIGFOLDER\$VCSACSVFILENAME"
If(!$VCSACSVFILEGET)
{
	CLS
	Write-Host "VCSA List CSV File not found"
	$VCSANAME = @()
	$CREATENEWRECORD = "" | Select VCSA, Site
	$CREATENEWRECORD.VCSA = "Create New Record" 
	$CREATENEWRECORD.Site = "NA" 
	$VCSANAME += $CREATENEWRECORD
	$VCSATEMPLIST = "" | Select VCSA, Site
	$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
	$VCSATEMPLIST.Site = $SITE
	Write-Host "Site Selected is"($VCSATEMPLIST.Site)
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
	$choice = Read-Host "On which VCSA do you wish to work with Host Profiles for site $SITE"
	$CHOICEPICKED = ($VCSASITELIST[$choice]).VCSA
	If($CHOICEPICKED -eq "Create New Record")
	{
		$VCSANAME = $VCSALIST
		Write-Host "Creating New Record Selected..."
		$VCSATEMPLIST = "" | Select VCSA, Site
		$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
		$VCSATEMPLIST.Site = $SITE 
		Write-Host "Site Selected is:"
		Write-Host $VCSATEMPLIST.Site
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

##Select System Cache Claim Rule
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select System Cache Option used for Auto Deploy"
$SYSCACHEOPTION = "Stateless with HD Cache","Stateful install on HD","Stateless on USB/SD","Stateful on USB/SD"
$countCL = 0   
Write-Host " " 
Write-Host "System Cache Options: " 
Write-Host " " 
foreach($oC in $SYSCACHEOPTION)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which Auto Deploy Configuration will these hosts use?"
$SYSCACHEOPTION = $SYSCACHEOPTION[$choice]
Write-Host "You have selected Auto Deploy Configuration $SYSCACHEOPTION"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select DNS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import DNS File or Create 1
$DNSCSVFILENAME = "DNSlist.csv"
$DNSCSVFILEGET = Get-Item "$CONFIGFOLDER\$DNSCSVFILENAME" -ErrorAction SilentlyContinue
$DNSCSVFILE = "$CONFIGFOLDER\$DNSCSVFILENAME"
If(!$DNSCSVFILEGET)
{
	CLS
	Write-Host "DNS List CSV File not found"
	$DNSNAME = @()
	$DNSTEMPLIST = "" | Select DNSServerList, Domain, SearchDomains, Site
	$DNSTEMPLIST.DNSServerList = Read-Host "Please provide a list of DNS servers for site $SITE in comma seperated format
	Example 8.8.8.8,8.4.4.4"
	$DNSTEMPLIST.Domain = Read-Host "Please provide the name of the Domain for these Hosts
	Example contso.com"
	$DNSTEMPLIST.SearchDomains = Read-Host "Please provide a list of Search Domains for site $SITE in comma seperated format
	Example contso.com,dmz.contso.com"
	$DNSTEMPLIST.Site = $SITE
	Write-Host "DNS Site Selected is"($DNSTEMPLIST.Site)
	$DNSNAME += $DNSTEMPLIST
	$DNSNAME | Export-CSV -NoTypeInformation -PATH $DNSCSVFILE
	$DNSSERVERLIST = $DNSTEMPLIST.DNSServerList
	$DNSDOMAIN = $DNSTEMPLIST.Domain
	$DNSSEARCHDOMAINS = $DNSTEMPLIST.SearchDomains
}
If($DNSCSVFILEGET)
{
	CLS
	Write-Host "DNS List CSV File found. Importing file..."
	$DNSLIST = Import-CSV -PATH $DNSCSVFILE
	If($DNSLIST.Site -eq $SITE)
	{
		Write-Host "Site $SITE DNS previously found, using DNS settings documented"
		$DNSSERVERLIST = ($DNSLIST | Where {$_.Site -eq $SITE}).DNSServerList
		$DNSDOMAIN = ($DNSLIST | Where {$_.Site -eq $SITE}).Domain
		$DNSSEARCHDOMAINS = ($DNSLIST | Where {$_.Site -eq $SITE}).SearchDomains
	}Else{
		$DNSARRAY = @()
		$DNSARRAY += $DNSLIST
		Write-Host "Site $SITE DNS Server not found"
		Write-Host "Creating New Record..."
		$DNSTEMPLIST = "" | Select DNSServerList, Domain, SearchDomains, Site
		$DNSTEMPLIST.DNSServerList = Read-Host "Please provide a list of DNS servers for site $SITE in comma seperated format
		Example 8.8.8.8,8.4.4.4"
		$DNSTEMPLIST.Domain = Read-Host "Please provide the name of the Domain for these Hosts
		Example contso.com"
		$DNSTEMPLIST.SearchDomains = Read-Host "Please provide a list of Search Domains for site $SITE in comma seperated format
		Example contso.com,dmz.contso.com"
		$DNSTEMPLIST.Site = $SITE
		Write-Host "DNS Site Selected is"($DNSTEMPLIST.Site)
		
		$DNSTEMPLIST | Export-CSV -NoTypeInformation -PATH $DNSCSVFILE -Confirm:$false -Append
		$DNSSERVERLIST = $DNSTEMPLIST.DNSServerList
		$DNSDOMAIN = $DNSTEMPLIST.Domain
		$DNSSEARCHDOMAINS = $DNSTEMPLIST.SearchDomains
		
	}
}
Write-Host "DNS Settings Include:"
Write-Host "DNS Server List"
Write-Host $DNSSERVERLIST
Write-Host "DNS Domain:"
Write-Host $DNSDOMAIN
Write-Host "DNS Search Domain(s):"
Write-Host $DNSSEARCHDOMAINS
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select NTP
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import NTP File or Create 1
$NTPCSVFILENAME = "NTPlist.csv"
$NTPCSVFILEGET = Get-Item "$CONFIGFOLDER\$NTPCSVFILENAME" -ErrorAction SilentlyContinue
$NTPCSVFILE = "$CONFIGFOLDER\$NTPCSVFILENAME"
If(!$NTPCSVFILEGET)
{
	CLS
	Write-Host "NTP List CSV File not found"
	$NTPNAME = @()
	$NTPTEMPLIST = "" | Select NTP, Site
	$NTPTEMPLIST.NTP = Read-Host "Please provide a list of NTP servers for site $SITE in comma seperated format
	Example: pool1.ntp.org, pool2.ntp.org, pool3.ntp.org, pool4.ntp.org, pool5.ntp.org
	Note: Please attempt to provide a minimum of 5 NTP Sources, as this is best practice per support.ntp.org, section 5.3.4, https://support.ntp.org/bin/view/Support/SelectingOffsiteNTPServers"
	$NTPTEMPLIST.Site = $SITE
	Write-Host "NTP Site Selected is"($NTPTEMPLIST.Site)
	$NTPNAME += $NTPTEMPLIST
	$NTPNAME | Export-CSV -NoTypeInformation -PATH $NTPCSVFILE
	$NTP = $NTPTEMPLIST.NTP
}
If($NTPCSVFILEGET)
{
	CLS
	Write-Host "NTP List CSV File found. Importing file..."
	Write-Host "Checking CSV for Site $SITE Listing"
	$NTPLIST = Import-CSV -PATH $NTPCSVFILE
	If($NTPLIST.Site -eq $SITE)
	{
		$NTP = ($NTPLIST | Where {$_.Site -eq $SITE}).NTP
		Write-Host "Based on $SITE selected, NTP server will be $NTP"
	}Else{
		Write-Host "Site NTP Server not found"
		Write-Host "Creating New Record..."
		$NTPTEMPLIST = "" | Select NTP, Site
		$NTPTEMPLIST.NTP = Read-Host Read-Host "Please provide a list of NTP servers for site $SITE in comma seperated format
	Example pool1.ntp.org, pool2.ntp.org"
		$NTPTEMPLIST.Site = $SITE 
		Write-Host "Site Selected is:"
		Write-Host $NTPTEMPLIST.Site

		$NTPTEMPLIST | Export-CSV -NoTypeInformation -PATH $NTPCSVFILE -Confirm:$false -Append
		$NTP = $NTPTEMPLIST.NTP
		
	}
}
Write-Host "NTP Selected is $NTP"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select SYSLOG
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import SYSLOG File or Create 1
$SYSLOGCSVFILENAME = "SYSLOGlist.csv"
$SYSLOGCSVFILEGET = Get-Item "$CONFIGFOLDER\$SYSLOGCSVFILENAME" -ErrorAction SilentlyContinue
$SYSLOGCSVFILE = "$CONFIGFOLDER\$SYSLOGCSVFILENAME"
If(!$SYSLOGCSVFILEGET)
{
	Write-Host "SYSLOG List CSV File not found"
	$SYSLOGNAME = @()
	$SYSLOGTEMPLIST = "" | Select SYSLOG, Site
	$SYSLOGTEMPLIST.SYSLOG = Read-Host "Please provide a SYSLOG FQDN or IP for site $SITE"
	$SYSLOGTEMPLIST.Site = $SITE
	Write-Host "Syslog Site Selected is"($SYSLOGTEMPLIST.Site)
	$SYSLOGNAME += $SYSLOGTEMPLIST
	$SYSLOGNAME | Export-CSV -NoTypeInformation -PATH $SYSLOGCSVFILE
	$SYSLOG = $SYSLOGTEMPLIST.SYSLOG
}
If($SYSLOGCSVFILEGET)
{
	CLS
	Write-Host "SYSLOG List CSV File found. Importing file..."
	$SYSLOGLIST = Import-CSV -PATH $SYSLOGCSVFILE
	If($SYSLOGLIST.Site -eq $SITE)
	{
		$SYSLOG = ($SYSLOGLIST | Where {$_.Site -eq $SITE}).SYSLOG
		Write-Host "Based on $SITE selected, SysLog server will be $SYSLOG"
	}Else{
		Write-Host "Site Syslog Server not found"
		Write-Host "Creating New Record..."
		$SYSLOGTEMPLIST = "" | Select SYSLOG, Site
		$SYSLOGTEMPLIST.SYSLOG = Read-Host "Please provide a SYSLOG FQDN or IP"
		$SYSLOGTEMPLIST.Site = $SITE 
		Write-Host "Site Selected is:"
		Write-Host $SYSLOGTEMPLIST.Site

		$SYSLOGTEMPLIST | Export-CSV -NoTypeInformation -PATH $SYSLOGCSVFILE -Confirm:$false -Append
		$SYSLOG = $SYSLOGTEMPLIST.SYSLOG
		
	}
}
Write-Host "SYSLOG Selected is $SYSLOG"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select SATP Claim Rules
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import SATP File or Create 1
$SATPCSVFILENAME = "SATPlist.csv"
$SATPCSVFILEGET = Get-Item "$CONFIGFOLDER\$SATPCSVFILENAME" -ErrorAction SilentlyContinue
$SATPCSVFILE = "$CONFIGFOLDER\$SATPCSVFILENAME"
If(!$SATPCSVFILEGET)
{
	CLS
	$CompleteSetting = $null
	$SATPNAME = @()
	DO{
		Write-Host "SATP List CSV File not found"
		$CorrectSetting = $null
			DO{
			$SATPTEMPLIST = "" | Select Vendor, Model, SATPname, ClaimOptions, Description, Options, PSPName, PSPOptions, Site
			$SATPTEMPLIST.Vendor = Read-Host "Please provide the Vendor Name
			Example: PURE"
			$SATPTEMPLIST.Model = Read-Host "Please provide the Model Name
			Example: FlashArray"
			$SATPTEMPLIST.SATPname = Read-Host "Please provide the SATP Name
			Example: VMW_SATP_ALUA"
			$SATPTEMPLIST.ClaimOptions = Read-Host "Please provide the Claim Options
			Example: tpgs_on
			Note: This can be left blank"
			$SATPTEMPLIST.Description = Read-Host "Please provide the Description
			Example: PURE FlashArray IO Operation Limit Rule
			Note: Please put something unique here"
			$SATPTEMPLIST.Options = Read-Host "Please provide the Options
			Example: ???
			Note: This can be left blank"
			$SATPTEMPLIST.PSPName = Read-Host "Please provide the PSPName
			Example: VMW_PSP_RR"
			$SATPTEMPLIST.PSPOptions = Read-Host "Please provide the PSPOptions
			Example: iops=1"
			$SATPTEMPLIST.Site = $SITE
			Write-Host "SATP Site Selected is"($SATPTEMPLIST.Site)
			CLS 
			Write-Host "Below is the details on the SATP you input:"
			$SATPTEMPLIST | Format-List
			
			Write-host "Is the SATP Claimrule Correct? (Default is Yes)" -ForegroundColor Yellow 
			$Readhost = Read-Host " ( y / n ) " 
			Switch ($ReadHost) 
			 { 
			   Y {Write-host "Yes selected, Continuing"; $CorrectSetting=$true} 
			   N {Write-Host "No selected, Recreate SATP Claim Rule"; $CorrectSetting=$false} 
			   Default {Write-Host "Default, Continuing"; $CorrectSetting=$true} 
			 } 
		}UNTIL($CorrectSetting -eq $true)
		$SATPNAME += $SATPTEMPLIST
		CLS
		Write-Host "Below is the details of all the SATP Claim Rules you have input:"
		$SATPNAME | Format-List
		Write-Host " "
		Write-host "Do You wish to add more SATP Claim Rule(s)" -ForegroundColor Yellow 
		$Readhost = Read-Host " ( y / n ) " 
		Switch ($ReadHost) 
		{ 
			Y {Write-host "Yes selected, Adding Another Record"; $CompleteSetting=$true} 
			N {Write-Host "No selected, All Records have been input"; $CompleteSetting=$false; $SATPTEMPLIST=$null} 
			Default {Write-Host "Default,  All Records have been input"; $CompleteSetting=$false} 
		} 
	}UNTIL(($CompleteSetting -eq $false))
	
	
	$SATPNAME | Export-CSV -NoTypeInformation -PATH $SATPCSVFILE
	$SATPARRAY = $SATPNAME
}
If($SATPCSVFILEGET)
{
	CLS
	Write-Host "SATP List CSV File found. Importing file..."
	$SATPLIST = Import-CSV -PATH $SATPCSVFILE
	If($SATPLIST.Site -eq $SITE)
	{
		$SATPARRAY = ($SATPLIST | Where {$_.Site -eq $SITE})
	}Else{
		$CompleteSetting = $null
		$SATPNAME = @()
		DO{
			Write-Host "SATP List for Site $SITE in CSV File not found"
			$CorrectSetting = $null
				DO{
				$SATPTEMPLIST = "" | Select Vendor, Model, SATPname, ClaimOptions, Description, Options, PSPName, PSPOptions, Site
				$SATPTEMPLIST.Vendor = Read-Host "Please provide the Vendor Name
				Example: PURE"
				$SATPTEMPLIST.Model = Read-Host "Please provide the Model Name
				Example: FlashArray"
				$SATPTEMPLIST.SATPname = Read-Host "Please provide the SATP Name
				Example: VMW_SATP_ALUA"
				$SATPTEMPLIST.ClaimOptions = Read-Host "Please provide the Claim Options
				Example: tpgs_on
				Note: This can be left blank"
				$SATPTEMPLIST.Description = Read-Host "Please provide the Description
				Example: PURE FlashArray IO Operation Limit Rule
				Note: Please put something unique here"
				$SATPTEMPLIST.Options = Read-Host "Please provide the Options
				Example: ???
				Note: This can be left blank"
				$SATPTEMPLIST.PSPName = Read-Host "Please provide the PSPName
				Example: VMW_PSP_RR"
				$SATPTEMPLIST.PSPOptions = Read-Host "Please provide the PSPOptions
				Example: iops=1"
				$SATPTEMPLIST.Site = $SITE
				Write-Host "SATP Site Selected is"($SATPTEMPLIST.Site)
				CLS 
				Write-Host "Below is the details on the SATP you input:"
				$SATPTEMPLIST | Format-List
				
				Write-host "Is the SATP Claimrule Correct? (Default is Yes)" -ForegroundColor Yellow 
				$Readhost = Read-Host " ( y / n ) " 
				Switch ($ReadHost) 
				 { 
				   Y {Write-host "Yes selected, Continuing"; $CorrectSetting=$true} 
				   N {Write-Host "No selected, Recreate SATP Claim Rule"; $CorrectSetting=$false} 
				   Default {Write-Host "Default, Continuing"; $CorrectSetting=$true} 
				 } 
			}UNTIL($CorrectSetting -eq $true)
			
			CLS
			Write-Host "Below is the details of all the SATP Claim Rules you have input:"
			$SATPTEMPLIST | Format-List
			Write-Host " "
			Write-host "Do You wish to add more SATP Claim Rule(s)" -ForegroundColor Yellow 
			$Readhost = Read-Host " ( y / n ) " 
			Switch ($ReadHost) 
			{ 
				Y {Write-host "Yes selected, Adding Another Record"; $CompleteSetting=$true} 
				N {Write-Host "No selected, All Records have been input"; $CompleteSetting=$false; $SATPTEMPLIST=$null} 
				Default {Write-Host "Default,  All Records have been input"; $CompleteSetting=$false} 
			} 
		}UNTIL(($CompleteSetting -eq $false))
		
		
		$SATPTEMPLIST | Export-CSV -NoTypeInformation -PATH $SATPCSVFILE -Confirm:$false -Append
		$SATPARRAY = $SATPTEMPLIST
	}
}
Write-Host "SATP Claim Rule(s) Selected Include:"
ForEach($SATP in $SATPARRAY)
{
	Write-Output $SATP | Format-List
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Input ESXi Local User Accounts
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Create Secure AES Keys for User and Password Management
$KeyFile = $CREDSFOLDER+"\"+"AES.key"
If (Test-Path $KeyFile){
Write-Host "AES File Exists"
$Key = Get-Content $KeyFile
Write-Host "Continuing..."
}Else{
$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | out-file $KeyFile
}
##Import LOCAL USER File or Create 1
$LOCALUSERCSVFILENAME = "LOCALUSERlist.csv"
$LOCALUSERCSVFILEGET = Get-Item "$CONFIGFOLDER\$LOCALUSERCSVFILENAME" -ErrorAction SilentlyContinue
$LOCALUSERCSVFILE = "$CONFIGFOLDER\$LOCALUSERCSVFILENAME"
If(!$LOCALUSERCSVFILEGET)
{
	CLS
	$CompleteSetting = $null
	$USERLISTEXPORTARRAY = @()
	DO{
		Write-Host "Local User List CSV File not found"
		$CorrectSetting = $null
			DO{
			#CSV Required fields
			#Name,Description,posixId,sshKey,roleName,PasswordPolicy,Site
			$LOCALUSERTEMPLIST = "" | Select Name,Description,posixId,sshKey,roleName,PasswordPolicy,Site
			$LOCALUSERTEMPLIST.Name = Read-Host "Please provide the User Name
			Example: root
			"
			$LOCALUSERTEMPLIST.Description = Read-Host "Please provide the Description of the user
			Example: Administrator
			"
			$LOCALUSERTEMPLIST.posixId = Read-Host "Please provide the posixId
			Example: 0
			"
			$LOCALUSERTEMPLIST.sshKey = Read-Host "Please provide the sshKey
			Example: ?
			Note: This can be left blank
			"
			$LOCALUSERTEMPLIST.roleName = Read-Host "Please provide the roleName
			Example: Admin
			"
			Write-Host "Select the Password Policy for this user account:"
			$LISTARRAY = @()
			$TEMPARRAY = "" | Select Type,Description
			$TEMPARRAY.Type = "Unchanged"
			$TEMPARRAY.Description = "Leave password unchanged for default account (root only)"
			$LISTARRAY += $TEMPARRAY
			$TEMPARRAY = "" | Select Type,Description
			$TEMPARRAY.Type = "Input"
			$TEMPARRAY.Description = "User input password configuration. This requires user input in EVERY Host Customization"
			$LISTARRAY += $TEMPARRAY
			$TEMPARRAY = "" | Select Type,Description
			$TEMPARRAY.Type = "Fixed"
			$TEMPARRAY.Description = "Fixed password configuration. This will prompt you to store the password for future use"
			$LISTARRAY += $TEMPARRAY
			$countCL = 0   
			Write-Host " " 
			foreach($oC in $LISTARRAY)
			{   
				Write-Output "[$countCL] $($oc.Type), Description: $($oc.Description)" 
				$countCL = $countCL+1  
			}
			Write-Host " "   
			$choice = Read-Host "Which #'d selection do you wish to choose for the Password Policy?"
			$LOCALUSERTEMPLIST.PasswordPolicy = ($LISTARRAY[$choice]).Type
			If($LOCALUSERTEMPLIST.PasswordPolicy -eq "Fixed")
			{
				##Create Secure XML Credential File for User Account Fixed password Policy
				$MgrCreds = $CREDSFOLDER+"\"+($LOCALUSERTEMPLIST.Name)+"_local_account_cred.xml"
				If (Test-Path $MgrCreds){
				Write-Host "$($LOCALUSERTEMPLIST.Name)_local_account_cred.xml file found"
				Write-Host "Continuing..."
				$ImportObject = Import-Clixml $MgrCreds
				$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
				$UserCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
				}
				Else {
				Write-Host "Please input the user password and click OK"
				$newPScreds = Get-Credential -UserName ($LOCALUSERTEMPLIST.Name) -message "Enter Local User $($LOCALUSERTEMPLIST.Name) Password:"
				$exportObject = New-Object psobject -Property @{
					UserName = $newPScreds.UserName
					Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
				}

				$exportObject | Export-Clixml $MgrCreds
				}
			}
			$LOCALUSERTEMPLIST.Site = $SITE
			Write-Host "Local User Site Selected is"($LOCALUSERTEMPLIST.Site)
			CLS 
			Write-Host "Below is the details on the Local User account you input:"
			$LOCALUSERTEMPLIST | Format-List
			
			Write-host "Is the Local User account Correct? (Default is Yes)" -ForegroundColor Yellow 
			$Readhost = Read-Host " ( y / n ) " 
			Switch ($ReadHost) 
			 { 
			   Y {Write-host "Yes selected, Continuing"; $CorrectSetting=$true} 
			   N {Write-Host "No selected, Recreate Local User Account"; $CorrectSetting=$false} 
			   Default {Write-Host "Default, Continuing"; $CorrectSetting=$true} 
			 } 
		}UNTIL($CorrectSetting -eq $true)
		$USERLISTEXPORTARRAY += $LOCALUSERTEMPLIST
		CLS
		Write-Host "Below is the details of all the Local User Accounts you have input:"
		$USERLISTEXPORTARRAY | Format-List
		Write-Host " "
		Write-host "Do You wish to add more Local User Accounts" -ForegroundColor Yellow 
		$Readhost = Read-Host " ( y / n ) " 
		Switch ($ReadHost) 
		{ 
			Y {Write-host "Yes selected, Adding Another Record"; $CompleteSetting=$true} 
			N {Write-Host "No selected, All Records have been input"; $CompleteSetting=$false; $LOCALUSERTEMPLIST=$null} 
			Default {Write-Host "Default,  All Records have been input"; $CompleteSetting=$false} 
		} 
	}UNTIL(($CompleteSetting -eq $false))
	
	
	$USERLISTEXPORTARRAY | Export-CSV -NoTypeInformation -PATH $LOCALUSERCSVFILE
	$LOCALUSERARRAY = $USERLISTEXPORTARRAY
}
If($LOCALUSERCSVFILEGET)
{
	CLS
	Write-Host "Local User List CSV File found. Importing file..."
	$LOCALUSERLISTEXPORTARRAY = Import-CSV -PATH $LOCALUSERCSVFILE
	If($LOCALUSERLISTEXPORTARRAY.Site -eq $SITE)
	{
		$LOCALUSERARRAY = ($LOCALUSERLISTEXPORTARRAY | Where {$_.Site -eq $SITE})
		#Verify that each fixed password has a xml file
		ForEach($LOCALUSERTEMPLIST in $LOCALUSERARRAY)
		{
			##Create Secure XML Credential File for User Account Fixed password Policy
			$MgrCreds = $CREDSFOLDER+"\"+($LOCALUSERTEMPLIST.Name)+"_local_account_cred.xml"
			If (Test-Path $MgrCreds){
			Write-Host "$($LOCALUSERTEMPLIST.Name)_local_account_cred.xml file found"
			Write-Host "Continuing..."
			$ImportObject = Import-Clixml $MgrCreds
			$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
			$UserCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
			}
			Else {
			Write-Host "$($LOCALUSERTEMPLIST.Name)_local_account_cred.xml file not found" -foregroundcolor red
			Write-Host "Please input the user password and click OK"
			$newPScreds = Get-Credential -UserName ($LOCALUSERTEMPLIST.Name) -message "Enter Local User $($LOCALUSERTEMPLIST.Name) Password:"
			$exportObject = New-Object psobject -Property @{
				UserName = $newPScreds.UserName
				Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
			}

			$exportObject | Export-Clixml $MgrCreds
			}
		}
	}Else{
		$CompleteSetting = $null
		$USERLISTEXPORTARRAY = @()
		DO{
			Write-Host "Local User List CSV File not found"
			$CorrectSetting = $null
				DO{
				#CSV Required fields
				#Name,Description,posixId,sshKey,roleName,PasswordPolicy,Site
				$LOCALUSERTEMPLIST = "" | Select Name,Description,posixId,sshKey,roleName,PasswordPolicy,Site
				$LOCALUSERTEMPLIST.Name = Read-Host "Please provide the User Name
				Example: root
				"
				$LOCALUSERTEMPLIST.Description = Read-Host "Please provide the Description of the user
				Example: Administrator
				"
				$LOCALUSERTEMPLIST.posixId = Read-Host "Please provide the posixId
				Example: 0
				"
				$LOCALUSERTEMPLIST.sshKey = Read-Host "Please provide the sshKey
				Example: ?
				Note: This can be left blank
				"
				$LOCALUSERTEMPLIST.roleName = Read-Host "Please provide the roleName
				Example: Admin
				"
				Write-Host "Select the Password Policy for this user account:"
				$LISTARRAY = @()
				$TEMPARRAY = "" | Select Type,Description
				$TEMPARRAY.Type = "Unchanged"
				$TEMPARRAY.Description = "Leave password unchanged for default account (root only)"
				$LISTARRAY += $TEMPARRAY
				$TEMPARRAY = "" | Select Type,Description
				$TEMPARRAY.Type = "Input"
				$TEMPARRAY.Description = "User input password configuration. This requires user input in EVERY Host Customization"
				$LISTARRAY += $TEMPARRAY
				$TEMPARRAY = "" | Select Type,Description
				$TEMPARRAY.Type = "Fixed"
				$TEMPARRAY.Description = "Fixed password configuration. This will prompt you to store the password for future use"
				$LISTARRAY += $TEMPARRAY
				$countCL = 0   
				Write-Host " " 
				foreach($oC in $LISTARRAY)
				{   
					Write-Output "[$countCL] $($oc.Type), Description: $($oc.Description)" 
					$countCL = $countCL+1  
				}
				Write-Host " "   
				$choice = Read-Host "Which #'d selection do you wish to choose for the Password Policy?"
				$LOCALUSERTEMPLIST.PasswordPolicy = ($LISTARRAY[$choice]).Type
				If($LOCALUSERTEMPLIST.PasswordPolicy -eq "Fixed")
				{
					##Create Secure XML Credential File for User Account Fixed password Policy
					$MgrCreds = $CREDSFOLDER+"\"+($LOCALUSERTEMPLIST.Name)+"_local_account_cred.xml"
					If (Test-Path $MgrCreds){
					Write-Host "$($LOCALUSERTEMPLIST.Name)_local_account_cred.xml file found"
					Write-Host "Continuing..."
					$ImportObject = Import-Clixml $MgrCreds
					$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
					$UserCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
					}
					Else {
					Write-Host "Please input the user password and click OK"
					$newPScreds = Get-Credential -UserName ($LOCALUSERTEMPLIST.Name) -message "Enter Local User $($LOCALUSERTEMPLIST.Name) Password:"
					$exportObject = New-Object psobject -Property @{
						UserName = $newPScreds.UserName
						Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
					}

					$exportObject | Export-Clixml $MgrCreds
					}
				}
				$LOCALUSERTEMPLIST.Site = $SITE
				Write-Host "Local User Site Selected is"($LOCALUSERTEMPLIST.Site)
				CLS 
				Write-Host "Below is the details on the Local User account you input:"
				$LOCALUSERTEMPLIST | Format-List
				
				Write-host "Is the Local User account Correct? (Default is Yes)" -ForegroundColor Yellow 
				$Readhost = Read-Host " ( y / n ) " 
				Switch ($ReadHost) 
				 { 
				   Y {Write-host "Yes selected, Continuing"; $CorrectSetting=$true} 
				   N {Write-Host "No selected, Recreate Local User Account"; $CorrectSetting=$false} 
				   Default {Write-Host "Default, Continuing"; $CorrectSetting=$true} 
				 } 
			}UNTIL($CorrectSetting -eq $true)
			$USERLISTEXPORTARRAY += $LOCALUSERTEMPLIST
			CLS
			Write-Host "Below is the details of all the Local User Accounts you have input:"
			$USERLISTEXPORTARRAY | Format-List
			Write-Host " "
			Write-host "Do You wish to add more Local User Accounts" -ForegroundColor Yellow 
			$Readhost = Read-Host " ( y / n ) " 
			Switch ($ReadHost) 
			{ 
				Y {Write-host "Yes selected, Adding Another Record"; $CompleteSetting=$true} 
				N {Write-Host "No selected, All Records have been input"; $CompleteSetting=$false; $LOCALUSERTEMPLIST=$null} 
				Default {Write-Host "Default,  All Records have been input"; $CompleteSetting=$false} 
			} 
		}UNTIL(($CompleteSetting -eq $false))
		
		
		$USERLISTEXPORTARRAY | Export-CSV -NoTypeInformation -PATH $LOCALUSERCSVFILE
		$LOCALUSERARRAY = $USERLISTEXPORTARRAY
	}
}
Write-Host "ESXi Local User Accounts Selected Include:"
ForEach($LOCALUSER in $LOCALUSERARRAY)
{
	Write-Output $LOCALUSER | Format-List
}
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

##Document Selections
Do
{
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Documenting User Selections"
Write-Host "Site:               			$SITE"
Write-Host "VCSA:               			$VCSA"
Write-Host "Auto Deploy System Cache Option:	$SYSCACHEOPTION"
Write-Host "DNS Server List:    			$DNSSERVERLIST"
Write-Host "DNS Domain:         			$DNSDOMAIN"
Write-Host "DNS Search Domains: 			$DNSSEARCHDOMAINS"
Write-Host "NTP List:           			$NTP"
Write-Host "SysLog Server:      			$SYSLOG"
Write-Host "SATP Claim Rule(s):"
ForEach($SATP in $SATPARRAY)
{
	Write-Output $SATP | Format-List
}
Write-Host "ESXi Local User Accounts:"
ForEach($LOCALUSER in $LOCALUSERARRAY)
{
	Write-Output $LOCALUSER | Format-List
}

	Write-host "Are the Above Settings Correct?" -ForegroundColor Yellow 
	$Readhost = Read-Host " ( y / n ) " 
	Switch ($ReadHost) 
	{ 
			Y {Write-host "Yes selected"; $VERIFICATION=$true} 
			N {Write-Host "No selected, Please Close this Window to Stop this Script"; $VERIFICATION=$false; PAUSE; CLS} 
			Default {Write-Host "Default,  Yes"; $VERIFICATION=$true} 
	}
}Until($VERIFICATION -eq $true)
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
$VCSAIP = ([System.Net.Dns]::GetHostEntry($VCSA)).AddressList.IPAddressToString
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
$choice = Read-Host "On which Cluster do you want to export the Host Profile from?"
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
$VMHOST = get-vmhost $VMHOST[$choice]
Write-Host "You have selected 
VMHost $VMHOST
Cluster $CLUSTER 
vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Enable CIM Service If it is not running. This is needed to properly monitor local storage on a VMHost
$CIMSERVICESTATUS = (Get-VMHost $VMHOST | Get-VMHostService | Where {$_.Key -eq 'sfcbd-watchdog'}).Running 	#CIM Server - Hardware Monitoring Service
If($CIMSERVICESTATUS -eq $false)
{
	Write-Host "CIM Server Service is not running on selected VMHost $VMHOST. Turning on CIM Server Service."
	Get-VMHost $VMHOST | Foreach {Start-VMHostService -HostService ($_ | Get-VMHostService | Where {$_.Key -eq 'sfcbd-watchdog'})}
	Get-VMHost $VMHOST | Foreach {Set-VMHostService -HostService ($_ | Get-VMHostService | where {$_.key -eq 'sfcbd-watchdog'}) -policy On}
}

##Remove Host Profile with Cluster Name if it exists
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$PROFILETEMPNAME = $CLUSTER.Name + "_temp"
Write-Host "Removing Any Previous Host Profiles with the Cluster name $PROFILETEMPNAME"
Get-VMHostProfile -Name (($CLUSTER.Name) + "_temp") -ErrorAction SilentlyContinue | Remove-VMHostProfile -Confirm:$false
Write-Host "Completed Removing Any Previous Host Profiles with the Cluster name $PROFILETEMPNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Export VMHost Config to Profile
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting VMHost profile from VMHost $VMHOST in Cluster $CLUSTER"
New-VMHostProfile -Name (($CLUSTER.Name) + "_temp") -ReferenceHost $VMHOST -Confirm:$false -Description "Automated Host Profile created for Cluster $CLUSTER, created from VMHost $VMHOST on Date $LOGDATE"
Write-Host "Completed exporting VMHost profile from VMHost $VMHOST in CLUSTER $CLUSTER"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Creates the spec where the cleanup is done
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating PowerShell Object SPEC and copy Host Profile Settings to it"
#Reference: https://www.retouw.nl/vsphere/generating-a-clean-host-profile-using-powercli/
$spec = New-Object VMware.Vim.HostProfileCompleteConfigSpec
#Get Host Profile that was generated previously
$hp = Get-VMHostProfile -Name (($CLUSTER.Name) + "_temp")
# Copies all properties of the new Host Profile to the spec
Copy-Property -From $hp.ExtensionData.Config -To $spec
Write-Host "Completed creating PowerShell Object SPEC and copy Host Profile Settings to it"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Disabling Physical Devices in Host Profile
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Removing Hardware specific references from SPEC Profile settings"
#$spec.ApplyProfile.Network.Vswitch=$null
#$spec.ApplyProfile.Network.VMportgroup=$null
#$spec.ApplyProfile.Network.HostPortGroup=$null
#Removing Physical Adapter from SPEC
Write-Host "Disabling Phyiscal Storage configuration from SPEC"
($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "iscsi_iscsiProfile_IscsiInitiatorProfile"}).Enabled=$false
($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Enabled=$True
##Disabling Pluggable Storage Architecture (PSA) Settings
Write-Host "Disabling Pluggable Storage Architecture (PSA) Settings"
Write-Host "Disabling PSA Device Sharing Profiles"
#How to List sub Profiles
#($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property 
$PSADEVICESHARINGPROFILES = (($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaDeviceSharingProfile"}).Profile
ForEach($o in $PSADEVICESHARINGPROFILES)
{
	$o.Enabled = $false
}
Write-Host "Disabling Boot Device Profiles"
$HOSTBOOTDEVICEPROFILES = ((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaBootDeviceProfile"})).Profile
ForEach($o in $HOSTBOOTDEVICEPROFILES)
{
	$o.Enabled = $false
}
Write-Host "Disabling PSA Device Setting Profiles"
$PSADEVICESETTINGPROFILES = ((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaDeviceSettingProfile"})).Profile
ForEach($o in $PSADEVICESETTINGPROFILES)
{
	$o.Enabled = $false
}
Write-Host "Disabling PSA Device Configuration Profiles"
$PsaDeviceConfigurationProfiles = ((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaDeviceConfigurationProfile"})).Profile
ForEach($o in $PsaDeviceConfigurationProfiles)
{
	$o.Enabled = $false
}
Write-Host "Disabling PSA device inquiry cache"
$PsaDeviceInquiryCacheProfiles = ((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaDeviceInquiryCacheProfile"})).Profile
ForEach($o in $PsaDeviceInquiryCacheProfiles)
{
	$o.Enabled = $false
}
##Disabling Native Multi-Pathing (NMP) Settings
Write-Host "Disabling Native Multi-Pathing (NMP) Settings"
#($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property
#(($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property |Where {$_.PropertyName -eq "nmp_nmpProfile_NmpDeviceProfile"}).Profile
Write-Host "Disabling PSP configuration for Device (NmpDeviceConfigurationProfiles)"
$NmpDeviceConfigurationProfiles = (((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property |Where {$_.PropertyName -eq "nmp_nmpProfile_NmpDeviceProfile"}).Profile).Property | Where {$_.PropertyName -eq "nmp_nmpProfile_NmpDeviceConfigurationProfile"}).Profile
ForEach($o in $NmpDeviceConfigurationProfiles)
{
	$o.Enabled = $false
}
Write-Host "Disabling SATP configuration for Device (NmpProfile_SatpDeviceProfiles)"
$NmpProfile_SatpDeviceProfiles = (((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property |Where {$_.PropertyName -eq "nmp_nmpProfile_NmpDeviceProfile"}).Profile).Property | Where {$_.PropertyName -eq "nmp_nmpProfile_SatpDeviceProfile"}).Profile
ForEach($o in $NmpProfile_SatpDeviceProfiles)
{
	$o.Enabled = $false
}
#nmp_nmpProfile_PathSelectionPolicyProfile
$nmpProfile_PathSelectionPolicyProfiles = (($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property |Where {$_.PropertyName -eq "nmp_nmpProfile_PathSelectionPolicyProfile"}).Profile
ForEach($o in $nmpProfile_PathSelectionPolicyProfiles)
{
	$o.Enabled = $false
}
##Disable vVOL
Write-Host "Disabling Storage Configuration>Virtual Volumes (VVOLS)"
ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "vvol_vvolProfile_VirtualVolumesProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable NFS User Host Configuration
#nfs_nfsUser_NfsUserProfile
Write-Host "Disabling Storage Configuration>NFS User Host Configuration"
ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nfs_nfsUser_NfsUserProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable Software FCOE Configuration
#fcoe_fcoeProfiles_FCoEProfile
Write-Host "Disabling Storage Configuration>Software FCOE Configuration"
ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "fcoe_fcoeProfiles_FCoEProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable vSAN Configuration
#vsan_vsanProfiles_VSANProfile
If($CLUSTER.VsanEnabled -eq $false)
{
	Write-Host "Disabling Storage Configuration>vSAN Configuration"
	ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "vsan_vsanProfiles_VSANProfile"}))
	{
		if ($p.Enabled){
			$p.Enabled=$False
		}
		foreach ($pa in $p.Property.Profile)
		{
			if ($pa.Enabled)
			{
				#$pa
				$pa.Enabled=$False
				#$pa
			}
			ForEach ($paa in $pa.Property.Profile)
			{
				If($paa.Enabled)
				{
					#$paa
					$paa.Enabled=$False
					#$paa
				}
			}
		}
	}
}ELSE{
	Write-Host "vSAN Enabled Cluster Detected. Leaving vSAN configuration enabled in Host Profile."
	ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "vsan_vsanProfiles_VSANProfile"}))
	{
		if ($p.Favorite){
			$p.Favorite=$True
		}
		foreach ($pa in $p.Property.Profile)
		{
			if ($pa.Favorite)
			{
				#$pa
				$pa.Favorite=$True
				#$pa
			}
			ForEach ($paa in $pa.Property.Profile)
			{
				If($paa.Favorite)
				{
					#$paa
					$paa.Enabled=$True
					#$paa
				}
			}
		}
	}
}
##Disable ESX Info
#info_esxInfo_EsxInfo
Write-Host "Disabling Other>ESX Info"
ForEach ($p in ($spec.ApplyProfile.Property.Profile |Where {$_.ProfileTypeName -eq "info_esxInfo_EsxInfo"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable DirectPath I/O Configuration
#pciPassThru_pciPassThru_PciPassThroughProfile
Write-Host "Disabling Advanced Configuration Settings>DirectPath I/O Configuration"
ForEach ($p in ($spec.ApplyProfile.Property.Profile |Where {$_.ProfileTypeName -eq "pciPassThru_pciPassThru_PciPassThroughProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable Device Alias Configuration
#deviceAlias_deviceAlias_DeviceAliasProfile
Write-Host "Disabling General System Settings>Device Alias Configuration"
ForEach ($p in ($spec.ApplyProfile.Property.Profile |Where {$_.ProfileTypeName -eq "deviceAlias_deviceAlias_DeviceAliasProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
Write-Host "Completed removing Hardware specific references from SPEC Profile settings"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Adding Configuration For Best Practices
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Adding Best Practices Configuration"

##Set CEIP Opt In to Yes
#key-vim-profile-host-OptionProfile-UserVars_HostClientCEIPOptIn
$CEIPOPTINSTATUS = ($spec.ApplyProfile.Option | where {$_.Key -eq 'key-vim-profile-host-OptionProfile-UserVars_HostClientCEIPOptIn'})
If($CEIPOPTINSTATUS)
{
	Write-Host "CEIP Settings verified. Enforcing Host Client CEIP Opt In to yes"
	(((($spec.ApplyProfile.Option | where {$_.Key -eq 'key-vim-profile-host-OptionProfile-UserVars_HostClientCEIPOptIn'}).Policy | Where {$_.Id -eq 'ConfigOptionPolicy'}).PolicyOption | Where {$_.Id -eq 'FixedConfigOption'}).Parameter |Where {$_.Key -eq 'value'}).Value = '1' #0 for ask, 1 for yes, 2 for no
	Write-Host "Setting Host Client CEIP Opt In as a Favorite"
	($spec.ApplyProfile.Option | where {$_.Key -eq 'key-vim-profile-host-OptionProfile-UserVars_HostClientCEIPOptIn'}).Favorite = $True
	Write-Host "Completed enforcing Host Client CEIP Opt In to yes"
}Else{
	Write-Host "Host Client CEIP Opt In not found. Adding configuration"
	$configOption = $null
	$configOption = New-Object VMware.Vim.OptionProfile
	$configOption[0].Key = 'key-vim-profile-host-OptionProfile-UserVars_HostClientCEIPOptIn'
	$configOption[0].ProfileTypeName = 'OptionProfile'
	$configOption[0].ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
	$configOption[0].Enabled = $true
	$configOption[0].Favorite = $true
	$configOption[0].Policy = New-Object VMware.Vim.ProfilePolicy
	$configOption[0].Policy[0].Id = 'ConfigOptionPolicy'
	$configOption[0].Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$configOption[0].Policy[0].PolicyOption.Id = 'FixedConfigOption'
	$ParameterArray = @()
	$Parameter = $null
	$Parameter = New-Object VMware.Vim.KeyAnyValue
	$Parameter.Key = 'key'
	$Parameter.Value = 'UserVars.HostClientCEIPOptIn'
	$ParameterArray += $Parameter
	$Parameter = $null
	$Parameter = New-Object VMware.Vim.KeyAnyValue
	$Parameter.Key = 'value'
	$Parameter.Value = '1'
	$ParameterArray += $Parameter
	$configOption[0].Policy[0].PolicyOption.Parameter = $ParameterArray
	##Add Options to SPEC
	Write-Host "Adding Host Client CEIP Option Configuration to SPEC"
	$spec.ApplyProfile.Option +=@($configOption)
	Write-Host "Completed adding CEIP Option Configuration"
}

##Set Scratch Disk Requirement
Write-Host "Checking if Scratch Disk is set as a requirement under Advanced Configuration Settings > Advanced Options > ScratchConfig"
#ScratchConfig.ConfiguredScratchLocation
$SCRATCHSTATUS = $spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}
IF($SCRATCHSTATUS)
{
	Write-Host "Scratch Disk Configuration already exists :)"
	Write-Host "Setting Scratch Disk as Favorite"
	($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Favorite = $true
	($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Favorite
	IF(!($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption)
	{
		Write-Host "Scratch Disk configuration Policy Setting Not Found. Creating"
		($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
		($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption.Id = "UserInputAdvancedConfigOption"
		($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
		($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
		($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption.Parameter[0].Value = 'ScratchConfig.ConfiguredScratchLocation'
		($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption.Parameter[0].Key = 'key'	
	}
	IF(($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption.Id -ne "UserInputAdvancedConfigOption")
	{
		Write-Host "Scratch Disk configuration setting found, but not enforced, enforcing"
		($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation"}).Policy[0].PolicyOption.Id = "UserInputAdvancedConfigOption"
	}
	Write-Host "Completed Updating Scratch Disk Configuration"
}ELSE{
	Write-Host "Scratch Disk Configuration not found."
	Write-Host "Adding Scratch Disk to Configuration"
	$configOption = $null
	$configOption = New-Object VMware.Vim.OptionProfile
	$configOption[0].Key = 'key-vim-profile-host-OptionProfile-ScratchConfig_ConfiguredScratchLocation'
	$configOption[0].ProfileTypeName = 'OptionProfile'
	$configOption[0].ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
	$configOption[0].Enabled = $true
	$configOption[0].Favorite = $true
	$configOption[0].Policy = New-Object VMware.Vim.ProfilePolicy
	$configOption[0].Policy[0].Id = 'ConfigOptionPolicy'
	$configOption[0].Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$configOption[0].Policy[0].PolicyOption.Id = 'UserInputAdvancedConfigOption'
	$configOption[0].Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
	$configOption[0].Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
	$configOption[0].Policy[0].PolicyOption.Parameter[0].Value = 'ScratchConfig.ConfiguredScratchLocation'
	$configOption[0].Policy[0].PolicyOption.Parameter[0].Key = 'key'
	##Add Options to SPEC
	Write-Host "Adding Scratch Disk Configuration to SPEC"
	$spec.ApplyProfile.Option +=@($configOption)
	Write-Host "Completed adding Scratch Disk to Configuration"
}

##Set Keyboard Profile
#keyboardConfig_keyboardProfile_KeyboardProfile
Write-Host "Enforcing DCUI Keyboard Profile to US Default"
((($spec.ApplyProfile.Property.Profile |Where {$_.ProfileTypeName -eq "keyboardConfig_keyboardProfile_KeyboardProfile"}).Policy).PolicyOption).Parameter = $null

##Set SysLog for VMHost
Write-Host "Adding Syslog Settings"
$GetSysLogSpec = (((($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy).PolicyOption).Parameter | where {$_.key -eq "value"}).Value
If($GetSysLogSpec)
{
	#Enforce syslog setting
	(((($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy).PolicyOption).Parameter | where {$_.key -eq "value"}).Value = "udp://"+$SYSLOG+":514"
	#Verify Syslog Setting
	Write-Host "SysLog has now been updated to:"
	(((($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy).PolicyOption).Parameter | where {$_.key -eq "value"}).Value
	#Set Syslog as a Favorite
	Write-Host "Setting SysLog setting as a Favorite"
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Favorite=$true
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Favorite
	Write-Host "Setting SysLog Global Log Dir to Scratch Disk"
	$PolicyOption =  New-Object VMware.Vim.PolicyOption
	$PolicyOption[0].Id = 'SetDefaultConfigOption'
	$PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue
	$PolicyOption[0].Parameter[0].Key = 'key'
	$PolicyOption[0].Parameter[0].Value = 'Syslog.global.logDir'
	(($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logDir"}).Policy | Where {$_.Id -eq 'ConfigOptionPolicy'}).PolicyOption = $PolicyOption 
	Write-Host "Completed Adding Syslog Settings"
}
If(!$GetSysLogSpec)
{
	Write-Host "Syslog Settings not Found, adding Syslog settings."
	#Update Value to Fixed
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy[0].PolicyOption.Id = 'FixedConfigOption'
	#Create Parameters Array
	$TEMPARRAY = @()
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = 'key'
	$TEMP.Value = 'Syslog.global.logHost'
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = 'value'
	$TEMP.Value = "udp://"+$SYSLOG+":514"
	$TEMPARRAY += $TEMP
	#Replace Default Parameters
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy[0].PolicyOption.Parameter = $TEMPARRAY 
	#Verify Syslog Setting
	Write-Host "SysLog has now been updated to:"
	(((($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy).PolicyOption).Parameter | where {$_.key -eq "value"}).Value
	#Set Syslog as a Favorite
	Write-Host "Setting SysLog setting as a Favorite"
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Favorite=$true
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Favorite
	Write-Host "Setting SysLog Global Log Dir to Scratch Disk"
	$PolicyOption =  New-Object VMware.Vim.PolicyOption
	$PolicyOption[0].Id = 'SetDefaultConfigOption'
	$PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue
	$PolicyOption[0].Parameter[0].Key = 'key'
	$PolicyOption[0].Parameter[0].Value = 'Syslog.global.logDir'
	(($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logDir"}).Policy | Where {$_.Id -eq 'ConfigOptionPolicy'}).PolicyOption = $PolicyOption 
	Write-Host "Completed adding Syslog server for VMHost"
}

##Setting VMFS3_UseATSForHBOnVMFS5
$GetUseATSForHBOnVMFS5Spec = (($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-VMFS3_UseATSForHBOnVMFS5"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "value"}).Value
If($GetUseATSForHBOnVMFS5Spec.Count -gt 0)
{
	Write-Host "VMFS3_UseATSForHBOnVMFS5 Already Created"
	Write-Host "Setting VMFS3_UseATSForHBOnVMFS5 setting as a Favorite"
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-VMFS3_UseATSForHBOnVMFS5"}).Favorite=$true
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-VMFS3_UseATSForHBOnVMFS5"}).Favorite
	
}
If($GetUseATSForHBOnVMFS5Spec.count -lt 1)
{
	Write-Host "VMFS3_UseATSForHBOnVMFS5 Not Created. Creating Item."
	$configOption = $null
	$configOption = New-Object VMware.Vim.OptionProfile[] (10999)
	$configOption[0] = New-Object VMware.Vim.OptionProfile
	$configOption[0].ProfileTypeName = 'OptionProfile'
	$configOption[0].ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
	$configOption[0].Enabled = $true
	$configOption[0].Favorite = $true
	$configOption[0].Key = 'key-vim-profile-host-OptionProfile-'
	$configOption[0].Policy = New-Object VMware.Vim.ProfilePolicy[] (1)
	$configOption[0].Policy[0] = New-Object VMware.Vim.ProfilePolicy
	$configOption[0].Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$configOption[0].Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (2)
	$configOption[0].Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
	$configOption[0].Policy[0].PolicyOption.Parameter[0].Value = 'VMFS3.UseATSForHBOnVMFS5'
	$configOption[0].Policy[0].PolicyOption.Parameter[0].Key = 'key'
	$configOption[0].Policy[0].PolicyOption.Parameter[1] = New-Object VMware.Vim.KeyAnyValue
	$configOption[0].Policy[0].PolicyOption.Parameter[1].Value = '0'
	$configOption[0].Policy[0].PolicyOption.Parameter[1].Key = 'value'
	$configOption[0].Policy[0].PolicyOption.Id = 'FixedConfigOption'
	$configOption[0].Policy[0].Id = 'ConfigOptionPolicy'
	
	##Add Options to SPEC
	Write-Host "Adding VMFS3_UseATSForHBOnVMFS5 to SPEC"
	$spec.ApplyProfile.Option +=@($configOption)
}

##Enforce vCenter agent (vpxa) configurations
#key-vim-profile-host-OptionProfile-Config_Etc_motd
Write-Host "Enforcing VPXA Log settings. Advanced Configuration Settings > vCenter Agent (vpxa) Configurations"
(((((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Profile) |where {$_.ProfileTypeName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Policy `
| Where {$_.Id -eq "vpxaConfig.vpxaConfig.VpxaConfigProfilePolicy"}).PolicyOption | `
Where {$_.Id -eq "vpxaConfig.vpxaConfig.VpxaConfigProfilePolicyOption"}).Parameter |Where {$_.Key -eq "logLevel"}).Value = "info" #https://kb.vmware.com/s/article/1004795 Default for 5.x-6.x is verbose
Write-Host "Setting VPXA Log settings as Favorite"
(($spec.ApplyProfile.Property | where {$_.PropertyName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Profile | where {$_.ProfileTypeName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Favorite = $true
Write-Host "VPXA Logging set to :"
(((((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Profile) |where {$_.ProfileTypeName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Policy | Where {$_.Id -eq "vpxaConfig.vpxaConfig.VpxaConfigProfilePolicy"}).PolicyOption | Where {$_.Id -eq "vpxaConfig.vpxaConfig.VpxaConfigProfilePolicyOption"}).Parameter |Where {$_.Key -eq "logLevel"}).Value

##Enforce Graphics configuration
Write-Host "Enforcing Graphings Configuration. Advanced Configuration Settings > Graphics Configuration > Graphics Configuration "
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Profile | Where {$_.ProfileTypeName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "defaultGraphicsType"}).Value = "shared"
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Profile | Where {$_.ProfileTypeName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "sharedPassthruAssignmentPolicy"}).Value = "performance"
#(($spec.ApplyProfile.Property | where {$_.PropertyName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Profile | Where {$_.ProfileTypeName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Favorite = $true

##Enforce Host Profile Logging Level
Write-Host "Enforcing Host Profile Logging Level. Advanced Configuration Settings > Host Profile Log Configuration > Host Profile Log Configuration"
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Profile | Where {$_.ProfileTypeName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "traceEnabled"}).Value = $false
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Profile | Where {$_.ProfileTypeName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "logLevel"}).Value = "INFO" #Default is INFO. Change to DEBUG for higher logging
(($spec.ApplyProfile.Property | where {$_.PropertyName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Profile | Where {$_.ProfileTypeName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Favorite = $true

##Enforce Power System Configuration
#powerSystem_powerSystem_PowerSystemProfile
Write-Host "Setting Power System Profile as a Favorite. Advanced Configuration Settings > Power System Configuration > Power System"
(($spec.ApplyProfile.Property | where {$_.PropertyName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Profile | Where {$_.ProfileTypeName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Favorite = $true 
Write-Host "Enforcing Host Power System settings. Power System Configuration > Power System"
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Profile | Where {$_.ProfileTypeName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Policy | where {$_.Id -eq "powerSystem.powerSystem.CpuPolicy"}).PolicyOption.id = "powerSystem.powerSystem.DynamicCpuPolicyOption"
<#
#Power Options#
Balanced  --------  powerSystem.powerSystem.DynamicCpuPolicyOption  
High Performance--  powerSystem.powerSystem.StaticCpuPolicyOption
Low Power --------  powerSystem.powerSystem.LowCpuPolicyOption
Custome   --------  powerSystem.powerSystem.CustomCpuPolicyOption
Explicit option --- NoDefaultOption
#>

##Set NTP Settings
Write-Host "Setting NTP Settings"
$FIXEDNTPVERIFY = TRY{(($spec.ApplyProfile.Datetime.Policy | Where {$_.id -eq "NTPPolicy"}).PolicyOption | Where {$_.Id -eq "FixedNTPOption"})}CATCH{ }
If($FIXEDNTPVERIFY)
{
	$NTPARRAY = ($NTP.Split(',') | % { $_.Trim() })
	Write-Host "Setting NTP Server Setttings based on Site $SITE to $NTP"
	$spec.ApplyProfile.Datetime = New-Object VMware.Vim.DateTimeProfile
	$spec.ApplyProfile.Datetime.ProfileTypeName = 'DateTimeProfile'
	$spec.ApplyProfile.Datetime.ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
	$spec.ApplyProfile.Datetime.Enabled = $true
	$spec.ApplyProfile.Datetime.Policy = New-Object VMware.Vim.ProfilePolicy[] (1)
	$spec.ApplyProfile.Datetime.Policy[0] = New-Object VMware.Vim.ProfilePolicy
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Value = New-Object String[] ($NTPARRAY.Count)
	$NTPCL = 0
	ForEach($NTPL in $NTPARRAY)
	{
		$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Value[$NTPCL] = $NTPL
		$NTPCL = $NTPCL+1
	}
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Key = 'server'
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Id = 'FixedNTPOption'
	$spec.ApplyProfile.Datetime.Policy[0].Id = 'NTPPolicy'
	Write-Host "Setting NTP Settings as a Favorite"
	$spec.ApplyProfile.Datetime.Favorite = $true
}ELSE{
	Write-Host "NTP NOT configured on Parent of Host Profile, configuring Host Profile for NTP"
	$NTPARRAY = ($NTP.Split(',') | % { $_.Trim() })
	$spec.ApplyProfile.Datetime = New-Object VMware.Vim.DateTimeProfile
	$spec.ApplyProfile.Datetime.ProfileTypeName = 'DateTimeProfile'
	$spec.ApplyProfile.Datetime.ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
	$spec.ApplyProfile.Datetime.Enabled = $true
	$spec.ApplyProfile.Datetime.Policy = New-Object VMware.Vim.ProfilePolicy[] (1)
	$spec.ApplyProfile.Datetime.Policy[0] = New-Object VMware.Vim.ProfilePolicy
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Value = New-Object String[] ($NTPARRAY.Count)
	$NTPCL = 0
	ForEach($NTPL in $NTPARRAY)
	{
		$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Value[$NTPCL] = $NTPL
		$NTPCL = $NTPCL+1
	}
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Key = 'server'
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Id = 'FixedNTPOption'
	$spec.ApplyProfile.Datetime.Policy[0].Id = 'NTPPolicy'
	Write-Host "NTP Servers for Host Profile are now set to"
	((($spec.ApplyProfile.Datetime.Policy | Where {$_.id -eq "NTPPolicy"}).PolicyOption | Where {$_.Id -eq "FixedNTPOption"}).Parameter |Where {$_.key -eq "server"}).Value
	Write-Host "Setting NTP Settings as a Favorite"
	$spec.ApplyProfile.Datetime.Favorite = $true
}
Write-Host "Completed setting NTP Settings"


##Set DNS Settings
Write-Host "Setting Host Profile DNS Settings Based on Site"$SITE
$DNSSERVERLISTARRAY = ($DNSSERVERLIST.Split(',') | % { $_.Trim() })
$DNSSEARCHDOMAINSARRAY = ($DNSSEARCHDOMAINS.Split(',') | % { $_.Trim() })
#Set Host Profile DNS List
Write-Host "Setting Host Profile DNS Server List to $DNSSERVERLIST"
#((((($spec.ApplyProfile.Network.Property | Where {$_.PropertyName -eq "GenericNetStackInstanceProfile"}).Profile | Where {$_.ProfileTypeName -eq "GenericNetStackInstanceProfile"}).Property | Where {$_.PropertyName -eq "GenericDnsConfigProfile"}).Profile.Policy | Where {$_.Id -eq "DnsConfigPolicy"}).PolicyOption.Parameter | Where {$_.Key -eq "address"}).Value = $DNSSERVERLISTARRAY
#$spec.ApplyProfile.Network.Property[0].Profile[0].Property[0].Profile.Policy[0].PolicyOption.Parameter[0].Value = New-Object String[] ($DNSSERVERLISTARRAY.Count)
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'address'}).Value = New-Object String[] ($DNSSERVERLISTARRAY.Count)
$CL = $null
$CL = 0
ForEach($DNSSERVER in $DNSSERVERLISTARRAY)
{
	(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'address'}).Value[$CL] = $DNSSERVER
	$CL = $CL+1
}
Write-Host "Completed setting Host Profile DNS Server List is now set to:"
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'address'}).Value
#Set Host Profile DNS list to False (Change this to True if using DHCP)
Write-Host "Setting Host Profile DNS Server List from DHCP to False"
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'dhcp'}).Value = $False
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'dhcp'}).Value
Write-Host "Setting Host Profile DNS Domain name to: $DNSDOMAIN"
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'domainName'}).Value = $DNSDOMAIN
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'domainName'}).Value
Write-Host "Setting Host Search Domain(s) to: $DNSSEARCHDOMAINS"
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'searchDomain'}).Value = New-Object String[] ($DNSSEARCHDOMAINSARRAY.Count)
$CL = $null
$CL = 0
ForEach($DNSSEARCHDOMAIN in $DNSSEARCHDOMAINSARRAY)
{
	(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'searchDomain'}).Value[$CL] = $DNSSEARCHDOMAIN
	$CL = $CL+1
}
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'searchDomain'}).Value
Write-Host "Setting defaultTcpipStack > DNS Configuration as Favorite"
(((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Favorite = $TRUE
Write-Host "Completed setting Host Profile DNS Settings Based on Site"$SITE


##Set FIPS Mode Service Configuration
#security_FipsProfile_FipsProfile
Write-Host "Enforcing FIPS Mode Configuration for Service(s). Security and Services > Service Configuration > FIPS mode configuraiton"
#Specify Array of Services
$FIPSARRAY = @()
$FIPSTEMP = "" | Select Name, Enablement
$FIPSTEMP.Name = 'rhttpproxy'
$FIPSTEMP.Enablement = $True
$FIPSARRAY += $FIPSTEMP
$FIPSTEMP = "" | Select Name, Enablement
$FIPSTEMP.Name = 'ssh'
$FIPSTEMP.Enablement = $True
$FIPSARRAY += $FIPSTEMP
$PROFILES = @()
IF($FIPSARRAY)
{
	ForEach($FIPS in $FIPSARRAY)
	{
		$FIPSNAME = $FIPS.NAME
		Write-Host "Enforcing FIPS Mode Configuration for Service $FIPSNAME"
		$PROFILE = New-Object VMware.Vim.ProfileApplyProfileElement
		$PROFILE.Key = $FIPS.NAME #$FIPS.Key 
		$PROFILE.Enabled = $True
		$PROFILE.ProfileTypeName = 'security_FipsProfile_FipsProfile'
		$PROFILE.ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
		$PROFILE.Enabled = $True
		$PROFILE.Policy = New-Object VMware.Vim.ProfilePolicy
		$PROFILE.Policy[0].Id = 'security.FipsProfile.FipsProfilePolicy'
		$PROFILE.Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
		$PROFILE.Policy[0].PolicyOption[0].Id = 'security.FipsProfile.FipsProfilePolicyOption'	

		$TEMPARRAY = @()
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = 'service'
		$TEMP.Value = $FIPS.Name
		$TEMPARRAY += $TEMP
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = 'enabled'
		$TEMP.Value = $FIPS.Enablement
		$TEMPARRAY += $TEMP
		$PROFILE.Policy[0].PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue[] (2)
		$PROFILE.Policy[0].PolicyOption[0].Parameter = $TEMPARRAY
		$PROFILES += $PROFILE
		Write-Host "Completed enforcing FIPS Mode Configuration for Service $FIPSNAME"
	}

	($spec.ApplyProfile.Property | Where {$_.PropertyName -eq 'security_FipsProfile_FipsProfile'}).Profile = $PROFILES
}

##Set Service Configurations
#Set Service Array for Service Configuration
#Based on Default Settings except: ntpd,sfcbd-watchdog https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.vsphere.security.doc/GUID-37AB1F95-DDFD-4A5D-BD49-3249386FFADE.html
$SVCSARRAY = @()
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'DCUI'	#Direct Console UI
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'TSM'	#ESXi Shell
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'TSM-SSH'	#SSH Service
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $True
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'lbtd'	#Load-Based Teaming Daemon
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'ntpd'	#NTP Daemon
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'pcscd' #PC/SC Smart Card Daemon
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'sfcbd-watchdog'	#CIM Server - Hardware Monitoring Service
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'snmpd' #SNMP Server
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'vmsyslogd'	#Syslog Server
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $True
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'xorg'	#XOrg Server used for 3D GPU Passthrough
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP

$PROFILES = @()
IF($SVCSARRAY)
{
	ForEach($SVCS in $SVCSARRAY)
	{
		$SVCSNAME = $SVCS.NAME
		Write-Host "Enforcing SVCS Mode Configuration for Service $SVCSNAME"
		$PROFILE = New-Object VMware.Vim.ProfileApplyProfileElement
		$PROFILE.Key = $SVCSNAME #$SVCS.Key 
		$PROFILE.Enabled = $True
		$PROFILE.ProfileTypeName = 'service_serviceProfile_ServiceConfigProfile'
		$PROFILE.ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
		$PROFILE.Enabled = $True
		$PROFILE.Favorite = $SVCS.Favorite 
		$PROFILE.Policy += New-Object VMware.Vim.ProfilePolicy -Property @{Id='service.serviceProfile.ServiceNamePolicy'} 
		$PROFILE.Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
		$PROFILE.Policy[0].PolicyOption[0].Id = 'service.serviceProfile.ServiceNamePolicyOption'	
		
		$TEMPARRAY = @()
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = 'serviceId'
		$TEMP.Value = $SVCS.Name
		$TEMPARRAY += $TEMP
		$PROFILE.Policy[0].PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
		$PROFILE.Policy[0].PolicyOption[0].Parameter = $TEMPARRAY
		
		$PROFILE.Policy += New-Object VMware.Vim.ProfilePolicy -Property @{Id='service.serviceProfile.ServiceConfigPolicy'}
		$PROFILE.Policy[1].PolicyOption = New-Object VMware.Vim.PolicyOption
		If($SVCS.StartupPolicy -eq 'On')
		{
			Write-Host "Setting $SVCSNAME service to Start With Host"
			$PROFILE.Policy[1].PolicyOption[0].Id = 'service.serviceProfile.StartupPolicyOn'
		}
		If($SVCS.StartupPolicy -eq 'Off')
		{
			Write-Host "Setting $SVCSNAME service to Start and Stop Manually"
			$PROFILE.Policy[1].PolicyOption[0].Id = 'service.serviceProfile.StartupPolicyOff'
			$TEMPARRAY = @()
			$TEMP = New-Object VMware.Vim.KeyAnyValue
			$TEMP.Key = 'status'
			$TEMP.Value = $False #Turn on Service Check box
			$TEMPARRAY += $TEMP
			$PROFILE.Policy[1].PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
			$PROFILE.Policy[1].PolicyOption[0].Parameter = $TEMPARRAY
		}
		If($SVCS.StartupPolicy -eq 'Automatic')
		{
			Write-Host "Setting $SVCSNAME service to Start and Stop with Port Usage"
			$PROFILE.Policy[1].PolicyOption[0].Id = 'service.serviceProfile.StartupPolicyAutomatic'
			$TEMPARRAY = @()
			$TEMP = New-Object VMware.Vim.KeyAnyValue
			$TEMP.Key = 'status'
			$TEMP.Value = $False #Turn on Service Check box
			$TEMPARRAY += $TEMP
			$PROFILE.Policy[1].PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
			$PROFILE.Policy[1].PolicyOption[0].Parameter = $TEMPARRAY
		}
		
		$PROFILES += $PROFILE
		Write-Host "Completed enforcing SVCS Mode Configuration for Service $SVCSNAME"
	}

	($spec.ApplyProfile.Property | Where {$_.PropertyName -eq 'service_serviceProfile_ServiceConfigProfile'}).Profile = $PROFILES
}

##Enforing SATP Claimrule(s)
Write-Host "Enforcing/Setting SATP Claimrule(s)"
$CL = 0
($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile = New-Object VMware.Vim.ProfileApplyProfileElement[] ($SATPARRAY.count)
ForEach($SATP in $SATPARRAY)
{	
	Write-Host "Adding SATP Claimrule for"$SATP.Vendor
	Write-Output $SATP
	#($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile = New-Object VMware.Vim.ProfileApplyProfileElement
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL] = New-Object VMware.Vim.ProfileApplyProfileElement
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Key = $SATP.Vendor #'602486e6af0ae99dd02ebd6fd2ddf8c40e57eba85891cf64bb2864bf2e21c535'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Enabled = $True
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].ProfileTypeName = 'nmp_nmpProfile_SatpClaimrulesProfile'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Favorite = $true
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy = New-Object VMware.Vim.ProfilePolicy[] (2)
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0] = New-Object VMware.Vim.ProfilePolicy
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0].Id = 'nmp.nmpProfile.SatpClaimInformationPolicy'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0].PolicyOption[0].Id = 'nmp.nmpProfile.SatpClaimInformationPolicyOption'

	$SATPCLAIMARRAY = $null
	$SATPCLAIMARRAY = @()
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'satpName'
	$SATPCLAIMTEMP.Value = $SATP.SATPname
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'claimOptions'
	$SATPCLAIMTEMP.Value = $SATP.ClaimOptions
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'description'
	$SATPCLAIMTEMP.Value = $SATP.Description
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'options'
	$SATPCLAIMTEMP.Value = $SATP.Options
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'pspName'
	$SATPCLAIMTEMP.Value = $SATP.PSPName
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'pspOptions'
	$SATPCLAIMTEMP.Value = $SATP.PSPOptions
	$SATPCLAIMARRAY += $SATPCLAIMTEMP

	$TEMPARRAY = @()
	ForEach($SATPCLAIM in $SATPCLAIMARRAY)
	{
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = $SATPCLAIM.Key
		$TEMP.Value = $SATPCLAIM.Value
		$TEMPARRAY += $TEMP
	}
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0].PolicyOption[0].Parameter = $TEMPARRAY
	
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1] = New-Object VMware.Vim.ProfilePolicy
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1].Id = 'nmp.nmpProfile.SatpClaimTypePolicy'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1].PolicyOption = New-Object VMware.Vim.PolicyOption
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1].PolicyOption[0].Id = 'psa.common.VendorModelPolicyOption'
	
	#Select Vendor, Model, SATPname, ClaimOptions, Description, Options, PSPName, PSPOptions
	$SATPCLAIMARRAY = $null
	$SATPCLAIMARRAY = @()
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'vendorName'
	$SATPCLAIMTEMP.Value = $SATP.Vendor
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'model'
	$SATPCLAIMTEMP.Value = $SATP.Model
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$TEMPARRAY = @()
	ForEach($SATPCLAIM in $SATPCLAIMARRAY)
	{
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = $SATPCLAIM.Key
		$TEMP.Value = $SATPCLAIM.Value
		$TEMPARRAY += $TEMP
	}
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1].PolicyOption[0].Parameter = $TEMPARRAY
	$CL = $CL+1
	Write-Host "Completed adding SATP Claimrule for"$SATP.Vendor
}

##Enforce Clearing Host SNMP Configuration
Write-Host "Clearing any SNMP Configurations. General System Configuration > Management Agent Configuration > SNMP Agent Configuration > Other SNMP configuration"
(($spec.ApplyProfile.Property | Where {$_.PropertyName -eq "snmp_GenericAgentProfiles_GenericAgentConfigProfile"}).Profile.Property.Profile.Policy.PolicyOption.Parameter | Where {$_.Key -eq 'enable'}).Value = $false
#Create parameter array without communities parameter to clear any SNMP communities
$PARMARRAY = @()
$TEMPPARM = $null
$TEMPPARM = New-Object VMware.Vim.KeyAnyValue
$TEMPPARM.Key = "authentication"
$TEMPPARM.value = ""
$PARMARRAY += $TEMPPARM
$TEMPPARM = $null
$TEMPPARM = New-Object VMware.Vim.KeyAnyValue
$TEMPPARM.Key = "port"
$TEMPPARM.value = 161
$PARMARRAY += $TEMPPARM
$TEMPPARM = $null
$TEMPPARM = New-Object VMware.Vim.KeyAnyValue
$TEMPPARM.Key = "enable"
$TEMPPARM.value = $false
$PARMARRAY += $TEMPPARM
$TEMPPARM = $null
$TEMPPARM = New-Object VMware.Vim.KeyAnyValue
$TEMPPARM.Key = "hwsrc"
$TEMPPARM.value = "indications"
$PARMARRAY += $TEMPPARM
$TEMPPARM = $null
$TEMPPARM = New-Object VMware.Vim.KeyAnyValue
$TEMPPARM.Key = "largestorage"
$TEMPPARM.value = $true
$PARMARRAY += $TEMPPARM
$TEMPPARM = $null
$TEMPPARM = New-Object VMware.Vim.KeyAnyValue
$TEMPPARM.Key = "privacy"
$TEMPPARM.value = ""
$PARMARRAY += $TEMPPARM
$TEMPPARM = $null
$TEMPPARM = New-Object VMware.Vim.KeyAnyValue
$TEMPPARM.Key = "loglevel"
$TEMPPARM.value = "info" #info,warning,etc
$PARMARRAY += $TEMPPARM
($spec.ApplyProfile.Property | Where {$_.PropertyName -eq "snmp_GenericAgentProfiles_GenericAgentConfigProfile"}).Profile.Property.Profile.Policy.PolicyOption.Parameter = $PARMARRAY
Write-Host "Completed clearing any SNMP configurations"

<#
##NULL/Clear out CIM Profile
Write-Host "Removing any CIM Indication Subscriptions. General System Configuration > Management Agent Configuration > CIM Indication Subscriptions"											   
(($spec.ApplyProfile.Property | Where {$_.PropertyName -eq "cimIndications_cimIndicationsProfile_CimIndications"}).Profile).Property.Profile = $null

##Check for CIM Profile
$CIMPROFILE = (($spec.ApplyProfile.Property | Where {$_.PropertyName -eq "cimIndications_cimIndicationsProfile_CimIndications"}).Profile).Property.Profile
If(!$CIMPROFILE)
{
	Write-Host "CIM Profile not Found. Adding Profile to SPEC"
	$PROFILE = New-Object VMware.Vim.ProfileApplyProfileElement
	$PROFILE[0].Key = "54ec12f488aedfe9f59ee9b240fdbb046665f91fc88fbeca81de2b5ecdaa6e51" 
	$PROFILE[0].Enabled = $True
	$PROFILE[0].ProfileTypeName = "cimIndications_cimxmlIndications_CimXmlIndicationsProfile"
	$PROFILE[0].ProfileVersion = "$($spec.ApplyProfile.ProfileVersion)"
	$PROFILE[0].Favorite = $True
	$PROFILE[0].Policy = New-Object VMware.Vim.ProfilePolicy
	$PROFILE[0].Policy[0].Id = "cimIndications.cimxmlIndications.CimXmlIndicationsProfilePolicy"
	$PROFILE[0].Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$PROFILE[0].Policy[0].PolicyOption[0].Id = "cimIndications.cimxmlIndications.CimXmlIndicationsProfilePolicyOption"	
	$TEMPARRAY = @()
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "listenerClass"
	$TEMP.Value = "CIM_IndicationHandlerCIMXML"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "queryLanguage"
	$TEMP.Value = "WQL"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "filterSystemCreationClassName"
	$TEMP.Value = "CIM_ComputerSystem"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "listenerName"
	$TEMP.Value = "smx"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "filterSystemName"
	$TEMP.Value = "localhost"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "sourceNamespaces"
	$T = @()
	[string[]]$T += 'root/hpq'
	$TEMP.Value = $T
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "sourceNamespace"
	$TEMP.Value = "root/hpq"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "filterName"
	$TEMP.Value = "smx"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "listenerSystemName"
	$TEMP.Value = "localhost"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "filterClass"
	$TEMP.Value = "CIM_IndicationFilter"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "listenerDestination"
	$TEMP.Value = "http://localhost"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "listenerSystemCreationClassName"
	$TEMP.Value = "CIM_ComputerSystem"
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = "query"
	$TEMP.Value = "SELECT * FROM CIM_ProcessIndication"
	$TEMPARRAY += $TEMP
	$PROFILE[0].Policy[0].PolicyOption[0].Parameter = $TEMPARRAY
	
	(($spec.ApplyProfile.Property | Where {$_.PropertyName -eq "cimIndications_cimIndicationsProfile_CimIndications"}).Profile).Property.Profile = $PROFILE[0]
}
#>

#Functional. Opened VMware Support case to troubleshoot. Support Case # 20130695506/20140259207 
Write-Host "Setting Host Power System settings. Power System Configuration > Power System"
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Profile | Where {$_.ProfileTypeName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Policy | where {$_.Id -eq "powerSystem.powerSystem.CpuPolicy"}).PolicyOption.id = "powerSystem.powerSystem.DynamicCpuPolicyOption"
<#
Power Options
Balanced  --------  powerSystem.powerSystem.DynamicCpuPolicyOption  
High Performance--  powerSystem.powerSystem.StaticCpuPolicyOption
Low Power --------  powerSystem.powerSystem.LowCpuPolicyOption
Custome   --------  powerSystem.powerSystem.CustomCpuPolicyOption
Explicit option --- NoDefaultOption

#>

<#
##Disable IPv6 on VMHost Management
Write-Host "Enforcing Disablement of IPv6 for Hosts"
Write-Host "Disabling IPv6 for Host Management under -> General System Settings > Kernel Module Configuration > Kernel Module Configuration > Ketnel Module > tcpip4 > Kernel Module Parameter > ipv6"
((($spec.ApplyProfile.Property.Profile | where {$_.ProfileTypeName -eq 'kernelModule_moduleProfile_KernelModuleConfigProfile'}).Property.Profile | Where {$_.Key -eq 'KernelModuleProfile-tcpip4-key'}).Property.Profile | where {$_.Key -eq 'KernelModuleParamProfile-ipv6-key'}).Favorite = $true
(((($spec.ApplyProfile.Property.Profile | where {$_.ProfileTypeName -eq 'kernelModule_moduleProfile_KernelModuleConfigProfile'}).Property.Profile | Where {$_.Key -eq 'KernelModuleProfile-tcpip4-key'}).Property.Profile | where {$_.Key -eq 'KernelModuleParamProfile-ipv6-key'}).Policy.PolicyOption[0].Parameter | Where {$_.Key -eq 'parameterValue'}).Value = '0' #0 Disables IPv6, 1 Enables IPv6
#>
Write-Host "Completed adding Best Practices Configuration"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Setting Auto Deploy Best Practices Configuration"
#Note: If you dont use Auto Deploy, you may want to comment out this section

##Set Host System Cache
#Options "Stateless with HD Cache","Stateful install on HD","Stateless on USB/SD","Stateful on USB/SD"
If($SYSCACHEOPTION -eq "Stateless with HD Cache")
{
	Write-Host "Setting System Cache to 'Enable stateless caching on the host'"
#Note Value Setting is designed for Cisco UCS
$SYSTEMCACHEJSON = @"
{
    "PropertyName":  "systemCache_caching_CachingProfile",
    "Array":  false,
    "Profile":  [
                    {
                        "Enabled":  true,
                        "Policy":  [
                                       {
                                           "Id":  "systemCache.caching.CachingPolicy",
                                           "PolicyOption":  {
                                                                "Id":  "systemCache.caching.StatelessOption",
                                                                "Parameter":  [
                                                                                  {
                                                                                      "Key":  "firstDisk",
                                                                                      "Value":  "LSI,AVAGO,UCSB-MRAID12G,localesx,local"
                                                                                  },
                                                                                  {
                                                                                      "Key":  "overwriteVmfs",
                                                                                      "Value":  true
                                                                                  },
                                                                                  {
                                                                                      "Key":  "ignoreSsd",
                                                                                      "Value":  false
                                                                                  }
                                                                              ]
                                                            }
                                       }
                                   ],
                        "ProfileTypeName":  "systemCache_caching_CachingProfile",
                        "ProfileVersion":  "$($spec.ApplyProfile.ProfileVersion)",
                        "Property":  null,
                        "Favorite":  true,
                        "ToBeMerged":  null,
                        "ToReplaceWith":  null,
                        "ToBeDeleted":  null,
                        "CopyEnableStatus":  null,
                        "Hidden":  null
                    }
                ]
}
"@
	($spec.ApplyProfile.Property | Where{$_.PropertyName -eq "systemCache_caching_CachingProfile"}).Profile = (ConvertFrom-Json $SYSTEMCACHEJSON).Profile
}
If($SYSCACHEOPTION -eq "Stateful install on HD")
{
	Write-Host "Setting System Cache to 'Enable stateful installs on the host'"
#Note Value Setting is designed for Cisco UCS
$SYSTEMCACHEJSON = @"
{
    "PropertyName":  "systemCache_caching_CachingProfile",
    "Array":  false,
    "Profile":  [
                    {
                        "Enabled":  true,
                        "Policy":  [
                                       {
                                           "Id":  "systemCache.caching.CachingPolicy",
                                           "PolicyOption":  {
                                                                "Id":  "systemCache.caching.StatefulOption",
                                                                "Parameter":  [
                                                                                  {
                                                                                      "Key":  "firstDisk",
                                                                                      "Value":  "LSI,AVAGO,UCSB-MRAID12G,localesx,local"
                                                                                  },
                                                                                  {
                                                                                      "Key":  "overwriteVmfs",
                                                                                      "Value":  true
                                                                                  },
                                                                                  {
                                                                                      "Key":  "ignoreSsd",
                                                                                      "Value":  false
                                                                                  }
                                                                              ]
                                                            }
                                       }
                                   ],
                        "ProfileTypeName":  "systemCache_caching_CachingProfile",
                        "ProfileVersion":  "$($spec.ApplyProfile.ProfileVersion)",
                        "Property":  null,
                        "Favorite":  true,
                        "ToBeMerged":  null,
                        "ToReplaceWith":  null,
                        "ToBeDeleted":  null,
                        "CopyEnableStatus":  null,
                        "Hidden":  null
                    }
                ]
}
"@
	($spec.ApplyProfile.Property | Where{$_.PropertyName -eq "systemCache_caching_CachingProfile"}).Profile = (ConvertFrom-Json $SYSTEMCACHEJSON).Profile
}
If($SYSCACHEOPTION -eq "Stateless on USB/SD")
{
	Write-Host "Setting System Cache to 'Enable stateless caching to a USB disk on the host'"
$SYSTEMCACHEJSON = @"
{
    "PropertyName":  "systemCache_caching_CachingProfile",
    "Array":  false,
    "Profile":  [
                    {
                        "Enabled":  true,
                        "Policy":  [
                                       {
                                           "Id":  "systemCache.caching.CachingPolicy",
                                           "PolicyOption":  {
                                                                "Id":  "systemCache.caching.StatelessUSBOption",
                                                                "Parameter":  null
                                                            }
                                       }
                                   ],
                        "ProfileTypeName":  "systemCache_caching_CachingProfile",
                        "ProfileVersion":  "$($spec.ApplyProfile.ProfileVersion)",
                        "Property":  null,
                        "Favorite":  true,
                        "ToBeMerged":  null,
                        "ToReplaceWith":  null,
                        "ToBeDeleted":  null,
                        "CopyEnableStatus":  null,
                        "Hidden":  null
                    }
                ]
}
"@
	($spec.ApplyProfile.Property | Where{$_.PropertyName -eq "systemCache_caching_CachingProfile"}).Profile = (ConvertFrom-Json $SYSTEMCACHEJSON).Profile
}
If($SYSCACHEOPTION -eq "Stateful on USB/SD")
{
	Write-Host "Setting System Cache to 'Enable stateful installs to a USB disk on the host'"
$SYSTEMCACHEJSON = @"
{
    "PropertyName":  "systemCache_caching_CachingProfile",
    "Array":  false,
    "Profile":  [
                    {
                        "Enabled":  true,
                        "Policy":  [
                                       {
                                           "Id":  "systemCache.caching.CachingPolicy",
                                           "PolicyOption":  {
                                                                "Id":  "systemCache.caching.StatefulUSBOption",
                                                                "Parameter":  null
                                                            }
                                       }
                                   ],
                        "ProfileTypeName":  "systemCache_caching_CachingProfile",
                        "ProfileVersion":  "$($spec.ApplyProfile.ProfileVersion)",
                        "Property":  null,
                        "Favorite":  true,
                        "ToBeMerged":  null,
                        "ToReplaceWith":  null,
                        "ToBeDeleted":  null,
                        "CopyEnableStatus":  null,
                        "Hidden":  null
                    }
                ]
}
"@
	($spec.ApplyProfile.Property | Where{$_.PropertyName -eq "systemCache_caching_CachingProfile"}).Profile = (ConvertFrom-Json $SYSTEMCACHEJSON).Profile
}

##Enable Net Core Dump Profile
#How to Get JSON
#($spec.ApplyProfile.network.property |Where{$_.PropertyName -eq "netdumpConfig_netdump_NetdumpProfile"}).Profile | ConvertTo-Json -Depth 10
Write-Host "Setting Network Coredump Server to VCSA $VCSA IP $VCSAIP"
$COREDUMPJSON = @"
{
    "Enabled":  true,
    "Policy":  [
                   {
                       "Id":  "netdumpConfig.netdump.NetdumpProfilePolicy",
                       "PolicyOption":  {
                                            "Id":  "netdumpConfig.netdump.NetdumpProfilePolicyOption",
                                            "Parameter":  [
                                                              {
                                                                  "Key":  "HostVNic",
                                                                  "Value":  "vmk0"
                                                              },
                                                              {
                                                                  "Key":  "NetworkServerPort",
                                                                  "Value":  6500
                                                              },
                                                              {
                                                                  "Key":  "NetworkServerIP",
                                                                  "Value":  "$VCSAIP"
                                                              },
                                                              {
                                                                  "Key":  "Enabled",
                                                                  "Value":  true
                                                              }
                                                          ]
                                        }
                   }
               ],
    "ProfileTypeName":  "netdumpConfig_netdump_NetdumpProfile",
    "ProfileVersion":  "$($spec.ApplyProfile.ProfileVersion)",
    "Property":  null,
    "Favorite":  true,
    "ToBeMerged":  null,
    "ToReplaceWith":  null,
    "ToBeDeleted":  null,
    "CopyEnableStatus":  null,
    "Hidden":  null
}
"@
($spec.ApplyProfile.network.property |Where{$_.PropertyName -eq "netdumpConfig_netdump_NetdumpProfile"}).Profile = ConvertFrom-Json $COREDUMPJSON 
Write-Host "Completed setting Auto Deploy Best Practices Configuration"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

###Set ESXi Local User Accounts Config
##Reset all User Accounts to just root
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Resetting ESXi Local User Account Configuration to root Only"
#Create User Policy
$USERPARAMETERLIST = @()
$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
$USERPARAMETER.Key = "name"
$USERPARAMETER.Value = "root"
$USERPARAMETERLIST += $USERPARAMETER
$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
$USERPARAMETER.Key = "description"
$USERPARAMETER.Value = "Administrator"
$USERPARAMETERLIST += $USERPARAMETER
$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
$USERPARAMETER.Key = "posixId"
$USERPARAMETER.Value = 0
$USERPARAMETERLIST += $USERPARAMETER
$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
$USERPARAMETER.Key = "sshKey"
$USERPARAMETER.Value = ""
$USERPARAMETERLIST += $USERPARAMETER
$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
$USERPARAMETER.Key = "roleName"
$USERPARAMETER.Value = "Admin"
$USERPARAMETERLIST += $USERPARAMETER
$USERPOLICYOPTION = New-Object VMware.Vim.PolicyOption
$USERPOLICYOPTION.Id = "security.UserAccountProfile.UserPolicyOption"
$USERPOLICYOPTION.Parameter = $USERPARAMETERLIST
$USERPOLICY = New-Object VMware.Vim.ProfilePolicy
$USERPOLICY.Id = "security.UserAccountProfile.UserPolicy"
$USERPOLICY.PolicyOption = $USERPOLICYOPTION
#Create User Password Policy
$USERPASSWORDPOLICYOPTION = New-Object VMware.Vim.PolicyOption
$USERPASSWORDPOLICYOPTION.Id = "security.UserAccountProfile.DefaultAccountPasswordUnchangedOption"
$USERPASSWORDPOLICY = New-Object VMware.Vim.ProfilePolicy
$USERPASSWORDPOLICY.Id = "security.UserAccountProfile.PasswordPolicy"
$USERPASSWORDPOLICY.PolicyOption = $USERPASSWORDPOLICYOPTION
#Create Policy Array
$POLICYLIST = @()
$POLICYLIST += $USERPOLICY
$POLICYLIST += $USERPASSWORDPOLICY
#Create User Password Profile
$PROFILE = New-Object VMware.Vim.ProfileApplyProfileElement
$PROFILE.Key = "1"
$PROFILE.Enabled = $true
$PROFILE.ProfileTypeName = "security_UserAccountProfile_UserAccountProfile"
$PROFILE.ProfileVersion = $($spec.ApplyProfile.ProfileVersion)
$PROFILE.Favorite = $true
$PROFILE.Policy = $POLICYLIST
#Reset all accounts to just Root
((($spec.ApplyProfile.Property | Where {$_.PropertyName -eq "security_SecurityProfile_SecurityConfigProfile"}).Profile | Where {$_.ProfileTypeName -eq "security_SecurityProfile_SecurityConfigProfile"}).Property | Where {$_.PropertyName -eq "security_UserAccountProfile_UserAccountProfile"}).Profile = $PROFILE
Write-Host "Completed Resetting ESXi Local User Account Configuration to root Only"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"


##Create User Accounts
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating ESXi Local User Account(s)"
$N = 1
$USERPROFILELIST = @()
ForEach($USER in $LOCALUSERARRAY)
{
	#User Policy
	$USERPARAMETERLIST = @()
	$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
	$USERPARAMETER.Key = "name"
	$USERPARAMETER.Value = $USER.Name
	$USERPARAMETERLIST += $USERPARAMETER
	$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
	$USERPARAMETER.Key = "description"
	$USERPARAMETER.Value = $USER.Description
	$USERPARAMETERLIST += $USERPARAMETER
	$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
	$USERPARAMETER.Key = "posixId"
	$USERPARAMETER.Value = [int]$USER.posixId
	$USERPARAMETERLIST += $USERPARAMETER
	$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
	$USERPARAMETER.Key = "sshKey"
	$USERPARAMETER.Value = $USER.sshKey
	$USERPARAMETERLIST += $USERPARAMETER
	$USERPARAMETER = New-Object VMware.Vim.KeyAnyValue
	$USERPARAMETER.Key = "roleName"
	$USERPARAMETER.Value = $USER.roleName
	$USERPARAMETERLIST += $USERPARAMETER
	$USERPOLICYOPTION = New-Object VMware.Vim.PolicyOption
	$USERPOLICYOPTION.Id = "security.UserAccountProfile.UserPolicyOption"
	$USERPOLICYOPTION.Parameter = $USERPARAMETERLIST
	$USERPOLICY = New-Object VMware.Vim.ProfilePolicy
	$USERPOLICY.Id = "security.UserAccountProfile.UserPolicy"
	$USERPOLICY.PolicyOption = $USERPOLICYOPTION
	If($USER.PasswordPolicy -eq "Unchanged")
	{
		$USERPASSWORDPOLICYOPTION = New-Object VMware.Vim.PolicyOption
		$USERPASSWORDPOLICYOPTION.Id = "security.UserAccountProfile.DefaultAccountPasswordUnchangedOption"
		$USERPASSWORDPOLICY = New-Object VMware.Vim.ProfilePolicy
		$USERPASSWORDPOLICY.Id = "security.UserAccountProfile.PasswordPolicy"
		$USERPASSWORDPOLICY.PolicyOption = $USERPASSWORDPOLICYOPTION
	}
	If($USER.PasswordPolicy -eq "Input")
	{
		$USERPASSWORDPOLICYOPTION = New-Object VMware.Vim.PolicyOption
		$USERPASSWORDPOLICYOPTION.Id = "security.UserAccountProfile.UserInputPasswordConfigOption"
		$USERPASSWORDPOLICY = New-Object VMware.Vim.ProfilePolicy
		$USERPASSWORDPOLICY.Id = "security.UserAccountProfile.PasswordPolicy"
		$USERPASSWORDPOLICY.PolicyOption = $USERPASSWORDPOLICYOPTION
	}
	If($USER.PasswordPolicy -eq "Fixed")
	{
		#import xml password file
		$MgrCreds = $null
		$MgrCreds = $CREDSFOLDER+"\"+$USER.Name+"_local_account_cred.xml"
		$ImportObject = Import-Clixml $MgrCreds
		$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
		$UserCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
		#Decrypt password
		$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securestring)
		$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
		#Write-Host "Password is $password"
		$USERPASSWORDVALUE = New-Object VMware.Vim.PasswordField
		$USERPASSWORDVALUE.Value = $password
		$password = $null
		$USERPASSWORDPARAMETER = New-Object VMware.Vim.KeyAnyValue
		$USERPASSWORDPARAMETER.Key = "password"
		$USERPASSWORDPARAMETER.Value = $USERPASSWORDVALUE
		$USERPASSWORDPOLICYOPTION = New-Object VMware.Vim.PolicyOption
		$USERPASSWORDPOLICYOPTION.Id = "security.UserAccountProfile.FixedPasswordConfigOption"
		$USERPASSWORDPOLICYOPTION.Parameter = $USERPASSWORDPARAMETER
		$USERPASSWORDPOLICY = New-Object VMware.Vim.ProfilePolicy
		$USERPASSWORDPOLICY.Id = "security.UserAccountProfile.PasswordPolicy"
		$USERPASSWORDPOLICY.PolicyOption = $USERPASSWORDPOLICYOPTION
	}
	$POLICYLIST = @()
	$POLICYLIST += $USERPOLICY
	$POLICYLIST += $USERPASSWORDPOLICY
	#Build User Password Profile
	$PROFILE = New-Object VMware.Vim.ProfileApplyProfileElement
	$PROFILE.Key = $N
	$PROFILE.Enabled = $true
	$PROFILE.ProfileTypeName = "security_UserAccountProfile_UserAccountProfile"
	$PROFILE.ProfileVersion = $($spec.ApplyProfile.ProfileVersion)
	$PROFILE.Favorite = $true
	$PROFILE.Policy = $POLICYLIST
	$USERPROFILELIST += $PROFILE
	$N++
}
#Add All Profiles to User Settings (this replaces all existing users)
If($USERPROFILELIST.Count -gt 0)
{
	Write-Host "User Profile List Creation Completed"
	((($spec.ApplyProfile.Property | Where {$_.PropertyName -eq "security_SecurityProfile_SecurityConfigProfile"}).Profile | Where {$_.ProfileTypeName -eq "security_SecurityProfile_SecurityConfigProfile"}).Property | Where {$_.PropertyName -eq "security_UserAccountProfile_UserAccountProfile"}).Profile = $USERPROFILELIST
}Else{
	Write-Host "No user profiles list to update. Skipping"
}
Write-Host "Completed creating ESXi Local User Account(s)"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

###Write SPEC back to Host Profile
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Writing updated Host Profile SPEC back to Host Profile"
$hp.ExtensionData.UpdateHostProfile($spec)
Write-Host "Completed writing updated Host Profile SPEC back to Host Profile"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Update Name of Host Profile
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Renaming Host Profile post Creation/Configuration"
$PROFILEDATE = (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Get-VMHostProfile -Name (($CLUSTER.Name) + "_temp") | Set-VMHostProfile -Name (($CLUSTER.Name) + "_gw" + ($VMHOST.ExtensionData.Config.Network.IpRouteConfig.DefaultGateway))
Write-Host "Completed tenaming Host Profile post Creation/Configuration"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Apply Host Profile to Cluster
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Applying All VMHosts in Cluster $CLUSTER to Host Profile"(($CLUSTER.Name) + "_gw" + ($VMHOST.ExtensionData.Config.Network.IpRouteConfig.DefaultGateway)) 
$HOSTPROFILE = Get-VMHostProfile -Name (($CLUSTER.Name) + "_gw" + ($VMHOST.ExtensionData.Config.Network.IpRouteConfig.DefaultGateway))
$VMHOSTAPPLYLIST = Get-Cluster $CLUSTER | Get-VMHost | Where {$_.ExtensionData.Config.Network.IpRouteConfig.DefaultGateway -eq ($VMHOST.ExtensionData.Config.Network.IpRouteConfig.DefaultGateway)}
Apply-VMHostProfile -AssociateOnly -Entity $VMHOSTAPPLYLIST -Profile $HOSTPROFILE -Confirm:$false
Write-Host "Completed applying All VMHosts in Cluster $CLUSTER to Host Profile"(($CLUSTER.Name) + "_gw" + ($VMHOST.ExtensionData.Config.Network.IpRouteConfig.DefaultGateway))
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Export Host Profile to VPF File
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting Host Profile to VPF File"
##Specify Export File Info
$EXPORTFILENAME = (($CLUSTER.Name) + "_Cluster_" + $PROFILEDATE) + "_host_profile.vpf"
#Create Export Folder
$ExportFolder = $pwd.path+"\Export"
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}
#Specify Log File
$EXPORTFILE = $pwd.path+"\Export\"+$EXPORTFILENAME
Write-Host "Exporting Host Profile to VPF File to $EXPORTFILE"
Export-VMHostProfile -FilePath $EXPORTFILE -Profile $HOSTPROFILE
Write-Host "Completed exporting Host Profile to VPF File to $EXPORTFILE"
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