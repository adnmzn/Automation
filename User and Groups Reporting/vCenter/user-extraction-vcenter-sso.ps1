<# 
este script obtiene usuarios, grupos, roles y objetos
con acceso a vCenter.
#>

$listaVC = import-csv “C:\Users\aemonzon\vCenterList.csv”

foreach($vc in $listaVC){

    $user = $listaVC.User
    $pwd = $listaVC.Password
    $vcenter = $listaVC.FQDN

    $connection = connect-viserver -server $vcenter -user $user -password $pwd
   
    $si = Get-View ServiceInstance 
    $am = Get-View $si.Content.AuthorizationManager 
    $roleList = $am.RoleList 
    # Create the role map 
    $roleMap = @{} 
    # Add the roles to the map 
    foreach ($role in $roleList) {$roleMap[$role.RoleId] = $role}

    $permissions = $am.RetrieveAllPermissions()
    # Foreach permission 
    foreach ($permission in $permissions) 
        {
        $roleName = $roleMap[$permission.RoleId].Name     
        $entityView = Get-View $permission.Entity     
        $permission | Select-Object @{Name="vCenter";Expression={$connection.Name}},
                                    @{Name="Principal";Expression={$permission.Principal}},
                                    @{Name="Group";Expression={$permission.Group}},
                                    @{Name="RoleName"; Expression={$roleName}},
                                    @{Name="Object"; Expression={Get-Path $entityView}}}

}

Function Get-Path($entity)
            {
                $path = $entity.Name   
                while($entity.Parent -ne $null)
                    {     
                        $entity = Get-View -Id $entity.Parent            
                        if($entity.Name -ne "vm" -and $entity.Name -ne "host") 
                            {$path = $entity.Name + "\" + $path}        
                    }        
                $path } 


