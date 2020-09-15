<#------------------------------------------------------------------------------------------
 - Author: aemonzon@ar.ibm.com
<#----------------------------------------------------------------------------------------#>

$vCenter = "b02peivis001labvc.ciolab.ibm.com"

"vCenter Connection Test`n"

$user = read-host "User"
$pass = read-host "Pass" -AsSecureString

$credential = New-Object System.Management.Automation.PsCredential($user,$pass)

"`nConnecting to vCenter $vCenter`n"

try{
    connect-viserver -Server $vCenter -Credential $credential -ErrorAction Stop | Out-Null
    "Connection to vCenter $vCenter SUCCESSFUL"
    disconnect-viserver -confirm:$false
}
catch{
    if ($error[0].exception -like "*Could not resolve the requested VC server*"){
        "Connection to vCenter $vCenter FAILED - Unable to resolve the specified FQDN or Hostname!"
    }
    elseif($error[0].exception -like "*incorrect user name or password*"){
        "Connection to vCenter $vCenter FAILED - Incorrect user name or password!"
    }
        
}
