$date = get-date -Format d
$computer = [System.Environment]::MachineName
$username = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name

$result = New-object -TypeName psobject

$result | add-member -MemberType NoteProperty -Name Date -Value $($date)
$result | add-member -MemberType NoteProperty -Name Computer -Value $($computer)
$result | add-member -MemberType NoteProperty -Name Username -Value $($username)

$result | Format-Table | Export-Csv -Path .\test.csv -NoTypeInformation