$TimeServer = "GJKZ-DC-002V.AREA52.AFNOAPPS.USAF.MIL"
function Read-HostCustom {
    param($prompt)
    write-host $prompt -NoNewline
    $Host.UI.ReadLine()
}
while ($true){
    Write-Host "- Time Server Fix -"
    $computer = Read-Host "Input remote computer name or press Enter for local"
    cls
    if ($computer -eq ""){
        try {
            Write-Host "Applying time server fix to local computer" -ForegroundColor Green
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value $TimeServer
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name "AnnounceFlags" -Value 5
            Restart-Service w32time
            Write-Host "The time server has been set to $TimeServer and the Windows Time service has been restarted on the local computer." -ForegroundColor Green
        } catch {
            Write-Host "time server fix on local computer has failed" -ForegroundColor Red
        }
        sleep 3
    } else {
        if (Test-Connection $computer -Count 1 -ErrorAction SilentlyContinue){
            try {
                Write-Host "Applying time server fix to $computer" -ForegroundColor Green
                icm -ComputerName $computer -ArgumentList $TimeServer -ScriptBlock {
                    param($TimeServer)
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value $TimeServer
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name "AnnounceFlags" -Value 5
                    Restart-Service w32time
                }
                cls
                if (icm -ComputerName $computer -ArgumentList $TimeServer {param($TimeServer);(((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer").NtpServer -eq "$TimeServer") -and ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name "AnnounceFlags").AnnounceFlags -eq 5))}){
                    Write-Host "The time server has been set to $TimeServer and the Windows Time service has been restarted on $computer." -ForegroundColor Green
                } else {
                    Write-Host "time server fix on $computer has failed" -ForegroundColor Red
                }
            } catch {
                Write-Host "Applying time server fix to $computer has failed" -ForegroundColor Red
            }
        } else {
            Write-Host "$computer is offline" -ForegroundColor Red
        }
        sleep 3
    }
    Read-HostCustom -prompt "Press Enter to continue..."
    cls
}