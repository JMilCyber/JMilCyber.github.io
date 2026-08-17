while ($true){
    cls
    Write-Host "Remote HP Display Driver Install (silent)"
    Write-Host ""
    $computername = Read-Host "Enter computer name"
    if (Test-Connection $computername -Count 1 -EA SilentlyContinue){
        md "\\$computername\C$\temp\Intel_Iris" -ErrorAction SilentlyContinue
        copy-item "\\GJKZ-FS-09V\SoftwareShare\Unlicensed\DRIVERS\1. Computer Drivers\Intel_Iris" "\\$computername\C$\temp" -Recurse -Verbose
        icm $computername {
            pnputil /add-driver "C:\temp\Intel_Iris\*.inf" /install
            remove-item "C:\temp\Intel_Iris" -Recurse
        }
    } else {
        Write-Host "$computername is offline" -ForegroundColor Red
        sleep 3
    }
    $null = Read-Host "Press any key to continue"
}