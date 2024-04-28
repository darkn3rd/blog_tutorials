#!/usr/bin/env powershell
# Credit to Armin Reighter (2021-07-31): 
# * https://arminreiter.com/2021/07/3-ways-to-generate-passwords-in-powershell/
Function Get-RandomPassword ([int]$Length)
{
    Add-Type -AssemblyName System.Web
    $CharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($Length)
    $rng.GetBytes($bytes)
    $Return = New-Object char[]($Length)
    For ($i = 0 ; $i -lt $Length ; $i++)
    {
        $Return[$i] = $CharSet[$bytes[$i]%$CharSet.Length]
    }
    
    Return (-join $Return)
}

# null coalescing - default first arg
$num = if ($args[0]) { $args[0] } else { 32 }

Get-RandomPassword $num