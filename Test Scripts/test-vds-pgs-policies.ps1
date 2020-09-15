<#------------------------------------------------------------------------------------------
 Get VDS list and Portgroup list with security policies - Author: aemonzon@ar.ibm.com
<#----------------------------------------------------------------------------------------#>

$vCenter = "b23weivmw01.au.ap.ad.ibm.com"

"-------------------------------------------------------------"
"VDS list and Portgroup list with security policies"
"-------------------------------------------------------------`n"

$user = read-host "User"
$pass = read-host "Pass" -AsSecureString

$credential = New-Object System.Management.Automation.PsCredential($user,$pass)

"`nConnecting to vCenter $vCenter`n"

$connected = $false

try{
    connect-viserver -Server $vCenter -Credential $credential -ErrorAction Stop | Out-Null
    "Connection to vCenter $vCenter SUCCESSFUL`n"
    $connected = $true    
}

catch{
    if ($error[0].exception -like "*Could not resolve the requested VC server*"){
        "Connection to vCenter $vCenter FAILED - Unable to resolve the specified FQDN or Hostname!"
    }
    elseif($error[0].exception -like "*incorrect user name or password*"){
        "Connection to vCenter $vCenter FAILED - Incorrect user name or password!"
    }
        
}

if ($connected){
    "Getting list of Distributed Virtual Switches..."

    $vdslist = Get-VDSwitch

    if($vdslist -ne $null){

        ForEach($vds in $vdslist){
    
            write-host "`nDVS Name: " -nonewline 
            write-host "$vds" -ForegroundColor Green

            "`nGetting list of Distributed Virtual Portgroups on this DVS and respective security policies"

            $vdsPGs = $vds | Get-VDPortgroup | Where {$($_ | Get-View).Tag.Key -ne "SYSTEM/DVS.UPLINKPG"}

            ForEach($vdsPG in $vdsPGs){

                $dvspg_promiscuousmode = $($vdsPG | Get-VDSecurityPolicy).AllowPromiscuous
                $dvspg_forgedtransmits = $($vdsPG | Get-VDSecurityPolicy).ForgedTransmits
                $dvspg_macchanges = $($vdsPG | Get-VDSecurityPolicy).MacChanges
            
                "`nDVS Portgroup Name: " + $vdsPG
                "Promiscuous Mode: " + $dvspg_promiscuousmode
                "Forged Transmits: " + $dvspg_forgedtransmits
                "MAC Address Changes: " + $dvspg_macchanges

            }
    
        }
    
    }
    else{
        "No DVS were found on this vCenter"
    }    
    
    "`nDone!`n"
    disconnect-viserver -confirm:$false
}