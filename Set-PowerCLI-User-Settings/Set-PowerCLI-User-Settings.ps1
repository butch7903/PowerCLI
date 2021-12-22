##Set PowerCLI CEIP
Write-Host "Setting PowerCLI CEIP Policy to false"
$powercliCEIP = (Get-PowerCLIConfiguration -Scope AllUsers).ParticipateInCEIP
Do{
    $trash = Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false -ErrorAction SilentlyContinue
    $powercliCEIP = (Get-PowerCLIConfiguration -Scope AllUsers).ParticipateInCEIP
}Until($powercliCEIP -eq $false)
##Set PowerCLI Invalid Certificate Action
Write-Host "Setting PowerCLI Invalid Certificate Action Policy to Ignore"
$powercliCertAction = (Get-PowerCLIConfiguration -Scope AllUsers).InvalidCertificateAction
Do{
    $trash = Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Ignore -Confirm:$false -ErrorAction SilentlyContinue
    $powercliCertAction = (Get-PowerCLIConfiguration -Scope AllUsers).InvalidCertificateAction
}Until($powercliCertAction -eq "Ignore")
##Set PowerCLI Default Server Mode
Write-Host "Setting PowerCLI Default VI Server Mode Policy to Multiple"
$powercliDefaultServerMode = (Get-PowerCLIConfiguration -Scope AllUsers).DefaultVIServerMode
Do{
    $trash = Set-PowerCLIConfiguration -Scope AllUsers -DefaultVIServerMode Multiple -Confirm:$false -ErrorAction SilentlyContinue
    $powercliDefaultServerMode = (Get-PowerCLIConfiguration -Scope AllUsers).DefaultVIServerMode
}Until($powercliDefaultServerMode -eq "Multiple")
Set-PowerCLIConfiguration -Scope AllUsers -ProxyPolicy UseSystemProxy -Confirm;$false
Set-PowerCLIConfiguration -Scope AllUsers -DisplayDeprecationWarnings:$false -Confirm:$false
Set-PowerCLIConfiguration -Scope AllUsers -WebOperationTimeoutSeconds 300 -Confirm:$false


