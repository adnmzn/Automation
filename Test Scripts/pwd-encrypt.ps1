<#------------------------------------------------------------------------------------------
Password Encrypt Script - Author: aemonzon@ar.ibm.com
<#----------------------------------------------------------------------------------------#>

#encripto la pwd y la guardo en un txt
(get-credential).password | ConvertFrom-SecureString | set-content ".\password.txt"

#desencripto la pwd y creo un pscredential
$password = Get-Content ".\password.txt" | ConvertTo-SecureString 
$credential = New-Object System.Management.Automation.PsCredential("us\aemonzon",$password)

#pruebo el pscredential con connect-viserver
    try{           
        connect-viserver -server "b02peivis001labvc.ciolab.ibm.com" -Credential $credential -ErrorAction Stop | out-null
        "Connection to vCenter SUCCESSFUL"
        Disconnect-VIServer -confirm:$false    
    }

    catch{
        "Connection to vCenter $vCenterFQDN FAILED"  
    }        