param([switch]$Elevated)
function Check-Admin {
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((Check-Admin) -eq $false)  {
	if ($elevated)
	{
		# could not elevate, quit
	}
	else {
		Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
	}
	exit
}
try {
    echo "Creating Application Pool for iODS API"

    Import-Module WebAdministration

    $poolName = "NET v4.5 iODS"
	$AppPoolUser = "INT\opdbmanager.im"
	$AppPoolUserPw = "!C!#jT#D7nRm!"
    if(Test-Path "IIS:\AppPools\$poolName")
    {
        echo "App pool exists - removing"
        Remove-WebAppPool $poolName
        gci IIS:\AppPools
    }

    New-Item IIS:\AppPools\$poolName
    Set-ItemProperty -Path "IIS:\AppPools\$poolName" -Name enable32BitAppOnWin64 -Value 1
    Set-ItemProperty -Path "IIS:\AppPools\$poolName" -Name managedRuntimeVersion -Value 'v4.0'
	Set-ItemProperty -Path "IIS:\AppPools\$poolName" -Name processModel -Value @{userName=$AppPoolUser;password=$AppPoolUserPw;identitytype=3}
	Set-ItemProperty -Path "IIS:\AppPools\$poolName" -Name processModel.loadUserProfile -Value "True"
    $pool = Get-Item "IIS:\AppPools\$poolName"
    $pool.failure.rapidFailProtection = $false

    $pool | Set-Item
	
	$sitePath = 'IIS:\sites\Default Web Site\API-iODS'
	if (Test-Path $sitePath) {
			Set-ItemProperty -Path $sitePath -Name applicationPool -Value $poolName
		Write-Host "Application Pool updated successfully for site"
	}

    Write-Host "Operation completed successfully."
    Write-Host "Press Enter to exit."
    Read-Host
}
catch {
    Write-Host "An error occurred:"
    Write-Host $_.Exception.Message
    Read-Host
}