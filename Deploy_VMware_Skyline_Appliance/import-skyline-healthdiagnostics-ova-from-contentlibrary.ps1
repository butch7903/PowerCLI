<#
.NOTES
	Created by:		Russell Hamker
	Date:			July 21,2023
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

.SYNOPSIS
	This script will import a Skyline 4.0 Health Diagnostics OVA into the environment. This script was written to download and deploy VMware Skyline Diagnostics.
	If you wish to download the OVA as part of this process, please specify the URI (URL) from where to download the OVA from.

	#Other Notes:
	If you wish to deploy a different OVA run the below commands to get all the variables you need to input and update the code
	accordingly.
	$OVACONFIG = Get-OvfConfiguration $OVAPATH
	Write-Output $OVACONFIG
		
.DESCRIPTION
	Use this script to import a Skyline 4.0+ OVA. 
	
	Skyline does require specific password complexity for deployment.
	
	Details on Password Strength
		Valid Character class: Group 1: [a-z], [A-Z], [0-9]
		Valid Character class: Group 2: [~!@#$%^&|]
		Password Validation Rules

    Password must be of at least 8 characters
    Password must have characters from any of the 2 classes of Group1
    Password must have at least one character from class Group 2
    Password must not have space as one of the characters

	Sample
		Th1sISV@lid
		ThisIsVali$Too
	Additionally root password has requirements enforced by cracklib
	
.EXAMPLE
#Example 1 - Download and Deploy
$VCSA = "hamvc01.hamker.local"
$DeploymentType = "DownloadDeploy"
$URI = 'https://download2.vmware.com/software/vi/SHDV/VMware-Skyline-HealthDiagnostics-Appliance-4.0.3-23166264_OVF10.ova?AuthKey=exp=1714621091~hmac=b0575fb5783dfc00e3f30aa0502749be2f992c7a2f55a02e37565715a8d1a02a&params=%7B%22custnumber%22%3A%22d3AlQHRwZGoqZQ%3D%3D%22%2C%22sourcefilesize%22%3A%221.14+GB%22%2C%22dlgcode%22%3A%22SKYLINE_HD_VSPHERE%22%2C%22languagecode%22%3A%22en%22%2C%22source%22%3A%22BETA%22%2C%22downloadtype%22%3A%22manual%22%2C%22eula%22%3A%22N%22%2C%22downloaduuid%22%3A%229edeee18-abbc-4eaa-801a-36e2abab767d%22%2C%22purchased%22%3A%22N%22%2C%22dlgtype%22%3A%22Drivers+%26+Tools%22%2C%22productversion%22%3A%224.0.3%22%7D'
$VMNAME = "ham-skyline-col-101"
$HOSTNAME = "ham-skyline-col-101.hamker.local"
$ROOTPASSWORD = 'VMware1!'
$SHDADMINPASSWORD = 'VMware12345*'
$IPv4Address = "192.168.1.42"
$NetworkPrefix = "24" #Use an IP Calculator to get the NetworkPrefix of your Subnet Mask If needed
$DefaultGateway = "192.168.1.1"
$DNSServers = "192.168.1.32,192.168.1.33" #Must be Comma Seperated List
$NTPServers = "ntp1.net.prod.corp.dish-wireless.net,ntp2.net.prod.corp.dish-wireless.net,ntp3.net.prod.corp.dish-wireless.net" #Must be Comma Seperated List
./import-skyline-healthdiagnostics-ova-from-contentlibrary.ps1 -VCSA $VCSA -DeploymentType $DeploymentType -URI $URI -VMName $VMNAME -HostName $HOSTNAME -RootPassword $ROOTPASSWORD -SHDAdminPassword $SHDADMINPASSWORD -IPv4Address $IPv4Address -NetworkPrefix $NetworkPrefix -DefaultGateway $DefaultGateway -DNSServers $DNSServers -NTPServers $NTPServers

#>

param(
	[Parameter(Mandatory=$true)][String]$VCSA,
	[Parameter(Mandatory=$true)][ValidateSet('Deploy','DownloadDeploy')][String]$DeploymentType,
	[Parameter(Mandatory=$false)][String]$URI,
	[Parameter(Mandatory=$true)][String]$VMName,
	[Parameter(Mandatory=$true)][String]$HostName,
	[Parameter(Mandatory=$true)][String]$RootPassword,
	[Parameter(Mandatory=$true)][String]$SHDAdminPassword,
	[Parameter(Mandatory=$true)][ipaddress]$IPv4Address,
	[Parameter(Mandatory=$true)][ValidateSet('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32')][String]$NetworkPrefix,
	[Parameter(Mandatory=$true)][ipaddress]$DefaultGateway,
	[Parameter(Mandatory=$true)][String]$DNSServers,
	[Parameter(Mandatory=$true)][String]$NTPServers,
	[Parameter(Mandatory=$false)][Boolean]$Confirm
)
If($Confirm.Count -eq 0){$Confirm = $true}
If($DeploymentType -eq 'DownloadDeploy'){
	If(!$URI){
		Write-Error "Please Provide the Full URL (URI) to the OVA for download" -ErrorAction
	}
}

##Get Current Path
$pwd = pwd

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Import Module
#Import-Module VMware.PowerCLI
Import-Module VMware.Sdk.vSphere.vCenter
Import-Module VMware.Sdk.vSphere.Cis
Import-Module VMware.Sdk.vSphere.vCenter.Vm
Import-Module VMware.Sdk.vSphere.ContentLibrary
Import-Module VMware.Sdk.vSphere.vCenter.OVF

#Add Custom Function (by William Lam, Forked by Russell Hamker)
Function Get-SSLThumbprint {
	<#
	.NOTES
	Created by:		William Lam
	GitHub:			https://gist.github.com/lamw/988e4599c0f88d9fc25c9f2af8b72c92

	.SYNOPSIS
	Function to Get the SSL Thumbprint of a Website
	
	.DESCRIPTION
	Use this function to Get the SSL Thumbprint of a Website

	.EXAMPLE
	#Example
	$URL = "hamvc01.hamker.local"
	Get-SSLThumbprint $URL
	17:96:3C:50:25:C5:7E:30:1A:22:A1:B7:8D:97:39:4E:F4:F3:6A:DE
	#>
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('FullName')]
    [String]$URL
    )
if('IDontCarePolicy' -as [type]){}Else{
add-type @"
	using System.Net;
	using System.Security.Cryptography.X509Certificates;

		public class IDontCarePolicy : ICertificatePolicy {
		public IDontCarePolicy() {}
		public bool CheckValidationResult(
			ServicePoint sPoint, X509Certificate cert,
			WebRequest wRequest, int certProb) {
			return true;
			}
		}
"@
}
	If($URL -notcontains "https"){
		$URL = "https://" + $URL
	}
    [System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy

    # Need to connect using simple GET operation for this to work
    Try{
		Invoke-RestMethod -Uri $URL -Method Get | Out-Null
	}Catch{
	}
    $ENDPOINT_REQUEST = [System.Net.Webrequest]::Create("$URL")
	$array = @{}
    $SSL_THUMBPRINT = $ENDPOINT_REQUEST.ServicePoint.Certificate.GetCertHashString()
	$mod_ssl_thumbprint = $SSL_THUMBPRINT -replace '(..(?!$))','$1:'
    $array.ssl_thumbprint = $mod_ssl_thumbprint
	$array.issuer = $ENDPOINT_REQUEST.ServicePoint.Certificate.Issuer
	$array.subject = $ENDPOINT_REQUEST.ServicePoint.Certificate.Subject
	Write-Output $array
}

#Add Custom Functions (by Russell Hamker)
function Get-VMwareCISSession {
	<#
	.NOTES
	Created by:		Russell Hamker
	Date:			April 25, 2024
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

	.SYNOPSIS
	Function to Create a VMware CIS Session
	Reference: https://vdc-repo.vmware.com/vmwb-repository/dcr-public/423e512d-dda1-496f-9de3-851c28ca0814/0e3f6e0d-8d05-4f0c-887b-3d75d981bae5/VMware-vSphere-Automation-SDK-REST-6.7.0/docs/apidocs/operations/com/vmware/cis/session.create-operation.html

	.DESCRIPTION
	Use this function to Create a VMware CIS Session

	.EXAMPLE
	#Example
	$VCSA = "hamvc01.hamker.local"
	$Username = "rhamker"
	$Password = 'VMware1!'
	Get-VMwareCISSession -VCSA $VCSA -UserName $UserName -Password $Password
	
	#>
	param(
		[Parameter(Mandatory=$true)][string]$VCSA,
		[Parameter(Mandatory=$true)][string]$UserName,
		[Parameter(Mandatory=$true)][string]$Password
	)
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Content-Type", "application/json")
	$pair = "$($UserName):$($Password)"
	$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
	$basicAuthValue = "Basic $encodedCreds"
	$headers.Add("Authorization", "$basicAuthValue")
	$response = $null
	$uri = "https://$VCSA"+'/rest/com/vmware/cis/session'
	Try{
		$response = Invoke-RestMethod $uri -Method 'Post' -Headers $headers -SkipCertificateCheck -SkipHeaderValidation
	}Catch{
		$response = Invoke-RestMethod $uri -Method 'Post' -Headers $headers
	}
	If($response.value){
		Write-Output $response
	}Else{
		Write-Output $_.Exception
		Write-Error "Exception Occured"
	}
}

function Set-VMwareCISLibraryUploadURLItem {
	<#
	.NOTES
	Created by:		Russell Hamker
	Date:			April 25, 2024
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

	.SYNOPSIS
	Function to Create an Empty VMware Content Library Item
	Reference: https://vdc-repo.vmware.com/vmwb-repository/dcr-public/423e512d-dda1-496f-9de3-851c28ca0814/0e3f6e0d-8d05-4f0c-887b-3d75d981bae5/VMware-vSphere-Automation-SDK-REST-6.7.0/docs/apidocs/operations/com/vmware/content/library/item.update-operation.html
	
	.DESCRIPTION
	Use this function to Create an Empty VMware Content Library Item

	.EXAMPLE
	#Example
	$VCSA = "hamvc01.hamker.local"
	$Username = "rhamker"
	$Password = 'VMware1!'
	$LibraryName = "Content Library - HAMNAS02"
	$Name = "TinyLinux"
	$FileName = "TinyCore-current.iso"
	$URL = "http://www.patrickkremer.com/binuploads/TinyCore-current.iso"
	[securestring]$secStringPassword = ConvertTo-SecureString $Password -AsPlainText -Force
	[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($UserName, $secStringPassword)
	$VISERVER = Connect-VIServer -Server $VCSA -Credential $credObject
	If($VISERVER.IsConnected -eq $true){
		Write-Host "Successfully Connected to VI Server - $VCSA"
		$ContentLibrary = Get-ContentLibrary $LibraryName
		$LibraryID = ($ContentLibrary).Id
		If($LibraryID ){
			Write-Host "Successfully Found Content Library - $ContentLibrary"
			$SessionID = (Get-VMwareCISSession -VCSA $VCSA -UserName $UserName -Password $Password).value
			If($SessionID){
				Write-Host "Successfully Created CIS Session - $SessionID"
				$UploadOutput = Set-VMwareCISLibraryUploadURLItem -LibraryID $LibraryID -SessionID $SessionID -Name $Name -FileName $FileName -URL $URL
				If($UploadOutput.cached -eq $true){
					Write-Host "Upload Successful" -ForegroundColor Green
					Write-Output $UploadOutput
				}Else{
					Write-Output $UploadOutput
				}
			}Else{
				Write-Error "Could Not create Session ID" -ErrorAction Stop
			}
		}Else{
			Write-Error "Could Not Find Library ID" -ErrorAction Stop
		}
	}
	#>
	param(
		[Parameter(Mandatory=$true)][string]$LibraryID,
		[Parameter(Mandatory=$true)][string]$SessionID,
		[Parameter(Mandatory=$true)][string]$Name,
		[Parameter(Mandatory=$true)][string]$FileName,
		[Parameter(Mandatory=$true)][string]$URL
	)
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("vmware-api-session-id", "$SessionID")
	$headers.Add("Content-Type", "application/json")
	#Step1 - Create Library Item Id
	#Reference - https://developer.vmware.com/apis/vsphere-automation/latest/content/api/content/library/item/post/
	$body = $null
	$body = @{"library_id"="$LibraryID";"name"="$Name"} | ConvertTo-Json -Depth 10 -Compress
	$response = $null
	$uri = $null
	$uri = "https://$VCSA"+'/api/content/library/item'
	$response = $null
	Try{
		$response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck -SkipHeaderValidation
	}Catch{
		$response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers -Body $body
	}
	If($response){
		$library_item_id = $response
		#Step2 - Update Session Details
		#Reference - https://developer.vmware.com/apis/vsphere-automation/latest/content/api/content/library/item/update-session/post/
		If($URL -match "https|HTTPS"){
				$BASEURL = ([System.Uri]"$URL").Host
				Try{$StackExAPIResponse = Invoke-WebRequest -Uri "https://$BaseUrl" -TimeoutSec 3 -ErrorAction SilentlyContinue}
				Catch{}
				$servicePoint = [System.Net.ServicePointManager]::FindServicePoint("https://$BaseURL")
				$cert = $servicePoint.Certificate
				$chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
				$chain.build($cert)
				$certs = $chain.ChainElements | ForEach-Object {$_.Certificate}
				[System.Array]::Reverse($certs)
				$array = @()
				forEach($cert in $certs){
					#https://stackoverflow.com/questions/65083411/creating-pem-file-through-powershell
					$CertBase64 = [System.Convert]::ToBase64String($cert.RawData)
$Pem = @"
-----BEGIN CERTIFICATE-----
$CertBase64
-----END CERTIFICATE-----
"@
					$array += $Pem 
				}
				$CertificateChain = [system.String]::Join(" ", $array)
				#Trust Certificates
				ForEach($Cert in $array){
					$TrustedCertificatesCreateSpec = Initialize-TrustedCertificatesCreateSpec -CertText $cert
					Invoke-CreateContentTrustedCertificates -TrustedCertificatesCreateSpec $TrustedCertificatesCreateSpec
				}
				#Create Library Info
				$LibraryItemCertificateVerificationInfo = Initialize-LibraryItemCertificateVerificationInfo -Status "VERIFIED" -CertChain ($array | Select-Object -Last 1)
				#Create Model
				$LibraryItemModel = Initialize-LibraryItemModel -Id $library_item_id -LibraryId $LibraryID -ContentVersion "1" -CreationTime (Get-Date) -Description "$Name" -LastModifiedTime (Get-Date) -LastSyncTime (Get-Date) -MetadataVersion "1" -Name "$Name" -Cached $false -Size 0 -Type "MyType" -Version "1" -SourceId "MySourceId" -SecurityCompliance $false -CertificateVerificationInfo $LibraryItemCertificateVerificationInfo
				#$body = @{"library_item_id"="$library_item_id";"preview_info"=@{"cert_chain"=@([string]"$certchain.Thumbprint");"certificate_info"=@{"issuer"="string";"self_signed"=$true;"subject"="string";"x509"="string"}};"warning_behavior"=@(@{"ignored"=$true;"type"="SELF_SIGNED_CERTIFICATE"})} | ConvertTo-Json -Depth 10 -Compress
				$body = $LibraryItemModel | ConvertTo-Json -Depth 10 -Compress
		}Else{
			$body = @{"library_item_id"="$library_item_id"} | ConvertTo-Json -Depth 10 -Compress
		}
		$response = $null
		$uri = $null
		$uri = "https://$VCSA"+'/api/content/library/item/update-session'
		$response = $null
		Try{
			$response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck -SkipHeaderValidation
		}Catch{
			$response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers -Body $body
		}
		If($response){
			$UpdateSessionID = $response
			#Step3 - Prepare Transfer
			#Reference - https://developer.vmware.com/apis/vsphere-automation/latest/content/api/content/library/item/update-session/update_session_id/file/post/
			$body = @{"name"="$FileName";"source_endpoint"=@{"uri"="$URL"};"source_type"="PULL"} | ConvertTo-Json -Depth 10 -Compress
			$response = $null
			$uri = $null
			$uri = "https://$VCSA"+"/api/content/library/item/update-session/$UpdateSessionID/file"
			Try{
				$response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck -SkipHeaderValidation
			}Catch{
				$response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers -Body $body
			}
			If($response.status -eq "WAITING_FOR_TRANSFER"){
				#Step4 - Start Transfer
				$response = $null
				$uri = $null
				$uri = "https://$VCSA"+"/api/content/library/item/update-session/$UpdateSessionID"+'?action=complete'
				Try{
					$response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers -SkipCertificateCheck -SkipHeaderValidation
				}Catch{
					$response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers 
				}
				If($response.count -gt "0"){
					<#
					$array = "" | Select-Object Name,FileName,URI,Keep_in_storage,Status
					$array.Name = $Name
					$array.FileName = $FileName
					$array.URI = $URL
					$array.Keep_in_storage = $true
					$array.Status = "UPLOAD_STARTING"
					#Write-Output $array
					$response = $null
					#>
					#Step5 - Wait until process is completed
					Do{
						$uri = $null
						$uri = "https://$VCSA"+"/api/content/library/item/update-session/$UpdateSessionID"
						$response = $null
						Try{
							$response = Invoke-RestMethod $uri -Method 'GET' -Headers $headers -SkipCertificateCheck -SkipHeaderValidation
						}Catch{
							$response = Invoke-RestMethod $uri -Method 'GET' -Headers $headers
						}
						If($response.state -eq "ACTIVE"){
							Write-Progress -Activity "Upload Files to a Library Item - Upload Progress - $($Name):" -Status "$($response.client_progress)% Complete" -PercentComplete $response.client_progress
						}
						#Write-Output $response
					}Until($response.state -ne "ACTIVE")
					Write-Progress -Completed -Activity "make progress bar disappear" -ErrorAction SilentlyContinue
					#Step6 - Get Data for New Item
					#Write-Output $response
					If($response.state -eq "DONE"){
						$uri = $null
						$uri = "https://$VCSA"+"/rest/com/vmware/content/library/item/id:$library_item_id"
						$response = $null
						Try{
							$response = Invoke-RestMethod $uri -Method 'GET' -Headers $headers -SkipCertificateCheck -SkipHeaderValidation
						}Catch{
							$response = Invoke-RestMethod $uri -Method 'GET' -Headers $headers
						}
						If($response){
							Write-Output $response.value
						}else{
							Write-Output $response
							Write-Error "Error Detected" -ErrorAction Stop
						}
					}else{
						Write-Output $response
						Write-Error "Error Detected" -ErrorAction Stop
					}
				}
			}
		}
	}Else{
		Write-Output $_.Exception
		Write-Error "Exception Occured"
	}
}

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "log_" + $VCSA + "_import_skyline_healthdiagnostics_ova_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\log\"+$LOGFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")

##Check for VCSA Parameter
If(!$VCSA){
 Write-Error "No VCSA Specified"
}
IF($VCSA){
	Write-Host "VCSA Specified in Parameter is $VCSA"
}

##Create Secure AES Keys for User and Password Management
$KeyFile = $pwd.path+"\"+"AES.key"
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
$MgrCreds = $pwd.path+"\"+"$VCSA.xml"
If (Test-Path $MgrCreds){
	Write-Host "$VCSA.xml file found"
	Write-Host "Continuing..."
	$ImportObject = Import-Clixml $MgrCreds
	$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
	$MyCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
	If($DeploymentType -eq 'DownloadDeploy'){
		$Password = (New-Object PSCredential $MyCredential.UserName,$MyCredential.Password).GetNetworkCredential().Password
	}
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
	If($DeploymentType -eq 'DownloadDeploy'){
		$Password = (New-Object PSCredential $MyCredential.UserName,$MyCredential.Password).GetNetworkCredential().Password
	}
}

##Document Selections
Do
{
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Documenting User Selections"
Write-Host "VCSA: $VCSA"
Write-Host "Deployment Type: $DeploymentType"
If($URI){
	Write-Host "URL/URI: $URI"
}
Write-Host "VMName: $VMName"
Write-Host "Host Name: $HostName"
Write-Host "IPv4 Address: $IPv4Address"
Write-Host "Network Prefix: $NetworkPrefix"
Write-Host "Default Gateway: $DefaultGateway"
Write-Host "DNS Server List: $DNSServers"
Write-Host "NTP Server List: $NTPServers"
Write-host "Are the Above Settings Correct?" -ForegroundColor Yellow 
$Readhost = Read-Host " ( y / n ) " 
Switch ($ReadHost){ 
		Y {Write-host "Yes selected"; $VERIFICATION=$true} 
		N {Write-Host "No selected, Please Close this Window to Stop this Script"; $VERIFICATION=$false; PAUSE; CLS} 
		Default {Write-Host "Default,  Yes"; $VERIFICATION=$true} 
}
}Until($VERIFICATION -eq $true)
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Validate that the Self Signed VCSA Certificates do not cause an issue with PowerCLI Connecting to the VCSA
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User -Confirm:$false

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
Write-Host "Connecting to vCenter Server Appliance (VCSA) $VCSA"
$VISERVER = Connect-VIServer -server $VCSA -Credential $MyCredential
$VCSAIP = ([System.Net.Dns]::GetHostEntry($VCSA)).AddressList.IPAddressToString
Write-Host "Connected to VCSA $VIServer"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Download OVA to Content Library
If($DeploymentType -eq "DownloadDeploy"){
	#Specify URL to Download OVA From
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Deployment Style Download and Deploy Selected"
	#$URI = Read-Host "Please Provide the full URL to download the OVA"
	$EXTENDEDNAME = Split-Path $URI -Leaf
	$EXTENDEDNAMESPLIT = $EXTENDEDNAME -split ".ova"
	$OVANAME = $EXTENDEDNAMESPLIT[0]
	Write-Host "URL(URI): $URI"
	Write-Host "OVA Name: $OVANAME"
	Write-Host "OVA FileName: $($OVANAME+".ova")"
	Start-Sleep -Seconds 5
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

	##Select Content Library
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Clear-Host
	Write-Host "Select the Content Library of where the OVA is Stored on VCSA $VCSA"
	$CONTENTLIBRARYLIST = (Get-ContentLibrary | Select-Object Name | Sort-Object Name).Name
	If($CONTENTLIBRARYLIST.count -eq 0){
		Stop-Transcript
		Write-Error "No Content Libraries Detected in VCSA. Please create a Content Library and rerun this script" -ErrorAction Stop
	}
	If($CONTENTLIBRARYLIST.count -eq 1){
		Write-Host "Only the Single Content Library is Detected - $($CONTENTLIBRARYLIST.Name)"
		$CONTENTLIBRARY = Get-ContentLibrary -Name $CONTENTLIBRARYLIST
	}Else{
	$countCL = 0   
	Write-Host " " 
	Write-Host "Content Library: " 
	Write-Host " " 
	foreach($oC in $CONTENTLIBRARYLIST)
	{   
		Write-Output "[$countCL] $oc" 
		$countCL = $countCL+1  
	}
	Write-Host " "   
	$choice = Read-Host "Which Content Library do you wish to deploy the OVA from?"
	$CONTENTLIBRARY = Get-ContentLibrary -Name $CONTENTLIBRARYLIST[$choice]
	}
	Write-Host "You have selected Content Library $($CONTENTLIBRARY.Name) - Content Library ID $($CONTENTLIBRARY.Id) - on VCSA $VCSA"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

	#Import OVA
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Importing OVA to Selected Content Library $($CONTENTLIBRARY) on VCSA $VCSA"
	$LibraryID = $CONTENTLIBRARY.Id
	If($LibraryID){
		$SessionID = (Get-VMwareCISSession -VCSA $VCSA -UserName $MyCredential.UserName -Password $Password).value
		If($SessionID){
			Write-Host "Successfully Created CIS Session - $SessionID"
			#$UploadOutput = Set-VMwareCISLibraryUploadURLItem -LibraryID $LibraryID -SessionID $SessionID -Name $Name -FileName $FileName -URL $URL
			$UploadOutput = Set-VMwareCISLibraryUploadURLItem -LibraryID $LibraryID -SessionID $SessionID -Name $OVANAME -FileName $OVANAME+".ova" -URL $URI
			If($UploadOutput.cached -eq $true){
				Write-Host "Upload Successful" -ForegroundColor Green
				Write-Output $UploadOutput
			}Else{
				Write-Output $UploadOutput
			}
		}Else{
			Write-Error "Could Not create Session ID" -ErrorAction Stop
		}
	}Else{
		Write-Error "Could Not Find Library ID" -ErrorAction Stop
	}
	PAUSE
	Write-Host "Completed importing OVA to Selected Content Library $($CONTENTLIBRARY) on VCSA $VCSA"
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"

}

##Select CLUSTER
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select Cluster on VCSA $VCSA"
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
$choice = Read-Host "On which Cluster do you want to deploy to?"
$CLUSTER = Get-Cluster $CLUSTER[$choice]
#$VMHOST = ($CLUSTER | Get-VMHost | Sort-Object Name | Where-Object {$_.State -eq "Connected"})[0]
$VMHOST = (Get-Cluster $CLUSTER | Get-VMHost | Sort-Object Name | Where-Object {$_.State -eq "Connected"}) | Get-Random
Write-Host "You have selected Cluster $CLUSTER / VMHost $VMHOST on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Datastore
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select Datastore on Cluster $CLUSTER on VCSA $VCSA"
$DATASTORE = $VMHOST | Get-Datastore | Sort-Object Name
$countCL = 0   
Write-Host " " 
Write-Host "Datastores: " 
Write-Host " " 
foreach($oC in $DATASTORE)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "On which Datastore do you wish to deploy the OVA to?"
$DATASTORE = Get-Datastore $DATASTORE[$choice]
Write-Host "You have selected Datastore $DATASTORE on Cluster $CLUSTER on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Resource Pool/Optional
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Clear-Host
Write-Host "Optional - Select Resource Pool on vCenter $VCSA"
$RESOURCEPOOLLIST = Get-Cluster $CLUSTER | Get-ResourcePool | Sort-Object Name
IF($RESOURCEPOOLLIST.Count -gt 1){
$countCL = 0   
Write-Host " " 
Write-Host "ResourcePools: " 
Write-Host " " 
foreach($oC in $RESOURCEPOOLLIST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "On which Resource Pool do you wish to deploy the OVA to?"
$RESOURCEPOOL = (Get-Cluster $CLUSTER | Get-ResourcePool | Sort-Object Name)[$choice]
}Else{
	Write-Host "Only the Default ResourcePool is Detected - $($RESOURCEPOOLLIST.Name)"
	$RESOURCEPOOL = $RESOURCEPOOLLIST
}
Write-Host "You have selected Resource Pool $($RESOURCEPOOL.Name) on Cluster $CLUSTER on vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Network
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select Port Group on VMHost $VMHOST from VCSA $VCSA"
$PORTGROUP = Get-VMHost $VMHOST | Get-VirtualPortGroup | Sort-Object Name
$countCL = 0   
Write-Host " " 
Write-Host "ResourcePools: " 
Write-Host " " 
foreach($oC in $PORTGROUP)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "On which Virtual Port Group do you wish to deploy the OVA to?"
$PORTGROUP = (Get-VMHost $VMHOST | Get-VirtualPortGroup | Sort-Object Name)[$choice]
Write-Host "You have selected Port Group $PORTGROUP on Cluster $CLUSTER on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Content Library
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Clear-Host
Write-Host "Select the Content Library of where the OVA is Stored on VCSA $VCSA"
$CONTENTLIBRARYLIST = (Get-ContentLibrary | Select-Object Name | Sort-Object Name).Name
If($CONTENTLIBRARYLIST.count -eq 1){
	Write-Host "Only the Single Content Library is Detected - $($CONTENTLIBRARYLIST.Name)"
	$CONTENTLIBRARY = $CONTENTLIBRARYLIST
}Else{
$countCL = 0   
Write-Host " " 
Write-Host "Content Library: " 
Write-Host " " 
foreach($oC in $CONTENTLIBRARYLIST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which Content Library do you wish to deploy the OVA from?"
$CONTENTLIBRARY = $CONTENTLIBRARYLIST[$choice]
}
Write-Host "You have selected Content Library $($CONTENTLIBRARY) on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Content Library Item
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Clear-Host
Write-Host "Select the Content Library of where the OVA is Stored on VCSA $VCSA"
$CONTENTLIBRARYITEMLIST = (Get-ContentLibraryItem -ContentLibrary $CONTENTLIBRARY | Select-Object Name | Sort-Object).Name
$countCL = 0   
Write-Host " " 
Write-Host "Content Library Item List: " 
Write-Host " " 
foreach($oC in $CONTENTLIBRARYITEMLIST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which Content Library Item do you wish to deploy the OVA from?"
$CONTENTLIBRARYITEM = $CONTENTLIBRARYITEMLIST[$choice]
Write-Host "You have selected Content Library Item $($CONTENTLIBRARYITEM.Name) on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select VM Folder Location
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select the VM Folder for where the OVA is Stored on VCSA $VCSA"
$VMFOLDERLIST  = Get-Folder -Type VM | Sort-Object Name
$countCL = 0   
Write-Host " " 
Write-Host "Folder Item List: " 
Write-Host " " 
foreach($oC in $VMFOLDERLIST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which VM Folder do you wish to deploy the OVA to?"
$VMFOLDER = (Get-Folder -Type VM | Sort-Object Name)[$choice]
Write-Host "You have selected Content Library Item $($CONTENTLIBRARYITEM.Name) on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Import OVA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
##Skyline
$OVAPATH = Get-ContentLibraryItem -Name $CONTENTLIBRARYITEM -ContentLibrary $CONTENTLIBRARY #$CONTENTLIBRARYITEM #Get-ContentLibraryItem -Name "VMware-Skyline*" -ContentLibrary (Get-ContentLibrary -Name "mno-wpaas-mgmt")
$OVACONFIG = Get-OvfConfiguration -ContentLibraryItem $OVAPATH -Target $CLUSTER
$OVACONFIG.EULAs.Accept.Value = $true
$OVACONFIG.NetworkMapping.VM_Network.Value = $PORTGROUP
$OVACONFIG.Common.root_password.Value = $RootPassword
$OVACONFIG.Common.shd_admin_password.Value = $SHDAdminPassword
$OVACONFIG.Common.hostname.Value = $HostName
$OVACONFIG.Common.netipaddress.Value = $IPv4Address
$OVACONFIG.Common.netprefix.Value = $NetworkPrefix #=Subnet Mask
$OVACONFIG.Common.netgateway.Value = $DefaultGateway
$OVACONFIG.Common.netdns.Value = $DNSServers
$OVACONFIG.Common.netntp.Value = $NTPServers #"NTP Server List, Comma Seperated"
#####Output Selections
Write-Host "Importing OVA"
Write-Host "VCSA: "$VCSA
Write-Host "OVA: "$OVAPATH
Write-Host "Cluster: "$CLUSTER
Write-Host "VMHost: "$VMHOST
Write-Host "Datastore: "$DATASTORE
Write-Host "ResourcePool: "$RESOURCEPOOL
Write-Host "Port Group: "$PORTGROUP
Write-Host "Content Library: "$CONTENTLIBRARY
Write-Host "Content Item: "$CONTENTLIBRARYITEM
Write-Host "Host Name: "$HostName
Write-Host "IPv4 Address: "$IPv4Address
Write-Host "Network Prefix: "$NetworkPrefix
Write-Host "Default Gateway: "$DefaultGateway
Write-Host "DNS Server List: "$DNSServers
Write-Host "NTP Server List: "$NTPServers
Write-Host "VM Folder: "$VMFOLDER
Start-Sleep 10
Write-Host " "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Deploying VM - $VMNAME"
$VM = Get-ContentLibraryItem -Name $CONTENTLIBRARYITEM -ContentLibrary $CONTENTLIBRARY | New-VM –Name $VMNAME –VMHost $VMHOST -Datastore $DATASTORE -DiskStorageFormat Thin -OvfConfiguration $OVACONFIG -ResourcePool $RESOURCEPOOL -Location $VMFOLDER -Confirm:$false
Write-Host " "   
Write-Host "OVA Import Completed"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Upgrade VM Hardware to newest
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Upgrading VM Hardware Version - $VMNAME"
IF($VMHOST.Version -eq "7.0.0"){
	$VMVERSION = "vmx-19"
}
IF($VMHOST.Version -eq "8.0.0"){
	$VMVERSION = "vmx-20"
}
(Get-VM -Name $VMNAME).ExtensionData.UpgradeVM($VMVERSION)
Write-Host "Upgrading VM Hardware to Version $VMVERSION - $VMNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Power on VM
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Powering on Skyline - $VMNAME"
Start-VM -VM $VMNAME -Confirm:$false
Write-Host "Completed Powering on Skyline - $VMNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Document Next Steps
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Open a Browser to https://$HostName and login with the shd-admin account to configure" -ForegroundColor Green
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
If($Confirm -eq $true){
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
}