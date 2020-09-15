<#------------------------------------------------------------------------------------------
vCenter Connection Test Script - Author: aemonzon@ar.ibm.com
<#----------------------------------------------------------------------------------------#>

#region variables

$vclist = ""
$uid = ""
$results = ""
$logfilename = "./vc-connection-test-log.txt"

#endregion

#region funciones helper

function show-banner{

    Clear-Host
    "#####################################################################"
    "`t`t`tvCenter Connection Test Script"
    "#####################################################################`n"

}

function get-vclist{
    write-log "...reading list of vCenters...."
    get-content -path .\vCenterList.txt
}

function get-uid{

    write-log "...getting credentials for vcenter login..."

    [hashtable]$uid = @{}

    #US domain id

    $us_user = "us\aemonzon"
    $us_pwd = Get-Content .\secured-us-pwd.txt | ConvertTo-SecureString
    $us_cred = New-Object System.Management.Automation.PsCredential($us_user, $us_pwd)

    #CPCAD domain id

    $cpcad_user = "cpcad\aemonzon"
    $cpcad_pwd = Get-Content .\secured-cpcad-pwd.txt | ConvertTo-SecureString
    $cpcad_cred = New-Object System.Management.Automation.PsCredential($cpcad_user, $cpcad_pwd)

    $uid.usid = $us_cred
    $uid.cpcid = $cpcad_cred

    return $uid

}

function vc-connection{
    
    $logincred = ""
    $vcSuccessArrayList = [System.Collections.ArrayList]@()
    $vcFailedArrayList = [System.Collections.ArrayList]@()
    $vcConnection = $false
    [hashtable]$result = @{}    

    foreach ($vc in $vclist){

        $logincred = $uid.usid

        if ($vc -like "*.ash.cpc.ibm.com"){$logincred = $uid.cpcid}
    
        if ($vc -like "*.dal.cpc.ibm.com"){$logincred = $uid.cpcid}

        try{
            write-log "...testing connection to $vc..."
            Connect-VIServer -server $vc -Credential $logincred -ErrorAction Stop | out-null
            write-log "...connection to $vc successful..."
            $vcSuccessArrayList.add($vc)
            $vcConnection = $true    
        }

        catch{
            $error[0].exception.message
            write-log "...connection to $vc failed..."
            $vcFailedArrayList.add($vc)
            $vcConnection = $false
        }

        if($vcConnection){
            $hostlist = Get-VMHost
            write-log "...number of ESXi Hosts connected to this vCenter: $($hostlist.Count)"
            disconnect-viserver -confirm:$false
            write-log "...disconnected from vCenter $vc..."
        }        
        
    }

    $result.successArray = $vcSuccessArrayList
    $result.failedArray = $vcFailedArrayList

    write-log "...vcenter connection test finished..."    
    write-log "...number of successful vcenter connections: $($result.successArray.Count)"    
    write-log "...number of failed vcenter connections: $($result.failedArray.Count)"

    return $result
       
}

function get-hostlist{

    

}

function send-results{

    write-log "...sending log file..."

    $body = "<h2 style=""color:Tomato;"">vCenter Connection Script - Test</h2>"
    $body += “Summary: <br><br>”
    $body += “Number of successful vCenter connections: $($results.successArray.Count)<br>”
    $body += “Number of failed vCenter connections: $($results.failedArray.Count) <br><br>”
    $body += “Log file attached”    
       
    Send-MailMessage `
    -From "aemonzon@ar.ibm.com" `
    -To "pcs_x86@wwpdl.vnet.ibm.com" `
    -Subject "vCenter Connection Test" `
    -Body $body `
    -BodyAsHtml `
    -SmtpServer "na.relay.ibm.com" `
    -Port "25" `
    -Attachments $logfilename

}

function get-now{
    Get-Date -format "dd-MMM-yyyy-hh.mm.ss"
}

function write-log{

    Param([Parameter(Mandatory=$false)][string]$LineValue,[Parameter(Mandatory=$false)][string]$fcolor = "White")
    
    $LineValueWithDate = "$(get-now) - $LineValue"
	Add-Content -Path $logfilename -Value $LineValueWithDate
	Write-Host $LineValueWithDate -ForegroundColor $fcolor

}

#endregion

#region funciones hc



#endregion

#region main

show-banner

write-log "...script execution started...."

$vclist = get-vclist

$uid = get-uid

$results = vc-connection

write-log "...script execution finished...."

send-results

#endregion