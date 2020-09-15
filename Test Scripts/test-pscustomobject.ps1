param (
    [Parameter(Mandatory=$true)][int]$number
)

$digits = $number.ToString().ToCharArray()
$sum = 0

While ($digits.Length -ne 1) {
    $sum = 0
    $digits | ForEach { $sum += [int]$_.ToString() }
    $digits = $sum.ToString().ToCharArray()
    Write-Output "Intermediate result: $($sum)"
}

Write-Output $digits