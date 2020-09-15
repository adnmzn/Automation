clear-host
$vcConnectionFailed = 0
$vcConnectionSuccess= 0
$user = "us\aemonzon"
$pass = "Ozzy2015Riff2020"$vCenters = @('b02peivis001labvc.ciolab.ibm.com',`              'testvcenter1.ciolab.ibm.com',`              'b02peivis002labvc.ciolab.ibm.com',`              'bldresvmvc6.boulder.ibm.com',`              'testvcenter2.ciolab.ibm.com',`              'pokresvmvc6.pok.ibm.com')


ForEach ($vCenter in $vCenters){  

  try{
        "connection to vCenter $vCenter IN PROGRESS"
        connect-viserver -Server $vCenter -User $user -Password $pass -ErrorAction Stop | out-null
        "connection to vCenter $vCenter SUCCESSFUL"
        $vcConnectionSuccess += 1
        disconnect-viserver -confirm:$false

        "probando"
        "probando"
        "probando"
  
  }
  catch{
  "connection to vCenter $vCenter FAILED"
        $vcConnectionFailed += 1
  }
        
}  

"vCenter connections successful: $vcConnectionSuccess"
"vCenter connections failed: $vcConnectionFailed"