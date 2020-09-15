<#------------------------------------------------------------------------------------------
Password Encrypt Script for ESXi HC - Author: aemonzon@ar.ibm.com - FOR TESTING ONLY!!!
<#----------------------------------------------------------------------------------------#>

#password encrypt for US domain account

(get-credential).password | ConvertFrom-SecureString | set-content ".\us-pwd.txt"

#password encrypt for CPCAD domain account

(get-credential).password | ConvertFrom-SecureString | set-content ".\cpcad-pwd.txt"
