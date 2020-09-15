<#------------------------------------------------------------------------------------------
User Switch Script - Author: aemonzon@ar.ibm.com
<#----------------------------------------------------------------------------------------#>

$mainpath = "C:\Users\ADRIANEMILIOMonzon\Desktop\HC\HC-ESXi\HC-NEW\HC-ESXiv2\"
$vCenterCSV = $mainpath + "\vCenterList.csv”

$us_user = "us\aemonzon"
$us_pass = "Ozzy2015Riff2020"
$cpc_user = "cpcad\aemonzon"
$cpc_pass = "Ozzy2015Riff2020"

$listaVC = import-csv $vCenterCSV

ForEach($itemVC in $listaVC){

        $vCenterFQDN = $itemVC.vCenterFQDN

        if($vCenterFQDN -like "*.cpc.ibm.com"){
            $user = $cpc_user
            $pass = $cpc_pass        
        }else{
            $user = $us_user
            $pass = $us_pass
        }

        "Connecting to vCenter: $vCenterFQDN"

        try{
            "User: " + $user
            "Pass: " + $pass
            connect-viserver -server $vCenterFQDN -user $user -password $pass -ErrorAction Stop | out-null
            "Connection to vCenter $vCenterFQDN SUCCESSFUL"
            $vcConnectionSuccessCounter += 1
            $vcConnected = $true
        }

        catch{
            "Connection to vCenter $vCenterFQDN FAILED"        
            $vcConnectionFailedCounter += 1      
            $vcConnected = $false      
        }        
        
}
