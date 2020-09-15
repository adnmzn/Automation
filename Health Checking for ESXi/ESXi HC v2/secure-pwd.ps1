<#------------------------------------------------------------------------------------------
Password Encrypt Script for ESXi HC - Author: aemonzon@ar.ibm.com - v1
<#----------------------------------------------------------------------------------------#>

#password encrypt for US domain account

$us_cred = Get-Credential
$us_cred | Export-Clixml .\secured-us-cred.xml

#password encrypt for CPCAD domain account

$cpcad_cred = Get-Credential
$cpcad_cred | Export-Clixml .\secured-cpcad-cred.xml
