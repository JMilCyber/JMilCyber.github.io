while ($true){
    Write-Host "Get uninstall string for application"
    $computername = Read-Host "Input computer name"
    $applications = Invoke-Command -Computer $computername {Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*} | Where-Object {![string]::IsNullOrWhiteSpace($_.DisplayName) } | Select-Object DisplayName, installDate, UninstallString | Sort-Object DisplayName -ev systeminfoerror
    $message = "Select application to retrieve uninstall string"
    do {
        $application = $applications.displayname | Out-String -Stream | Out-GridView -Title $message -PassThru
    } while (!($application))
    $application = Invoke-Command -Computer $computername {Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*} | Where-Object {$_.DisplayName -eq $application } | Select-Object DisplayName, installDate, UninstallString | Sort-Object DisplayName -ev systeminfoerror
    $AppName = $application.Displayname
    $endapp = $application.UninstallString
    if ($endapp -like 'msiexec.exe*') {
        $String = $endapp -Replace "msiexec.exe","" -Replace "/I","" -Replace "/X",""
        $String = $String.Trim()
        $UninstallSyntax = "MsiExec.exe /X $String /qn"
        cls
        Write-Host "CMD command: /C $UninstallSyntax"
        Write-Host "Powershell command: Start-Process cmd.exe -ArgumentList `"/c $UninstallSyntax`""
        Write-Host "[U] uninstall $AppName on $computername [M] main menu"
        $option = Read-Host " "
        if ($option -eq "u") {       
            $Result = Invoke-Command -ComputerName $computername -ArgumentList $UninstallSyntax -ScriptBlock {
                Param($UninstallSyntax)
                $Exitness = Start-Process cmd.exe -ArgumentList "/c $UninstallSyntax" -Wait -PassThru
                $Exitness.ExitCode
            }
            if (($? -eq $True) -and ($result -eq 0)) {
                Write-Host "$AppName was successfully uninstalled on $computername"
            }
            elseif (($? -eq $True) -and ($result -eq 1641)) {
                Write-Host "$AppName uninstalled successfully on $computer, but the computer needs to restart"
            }
            elseif (($? -eq $True) -and ($result -eq 1603)) {
                Write-Host "Error 1603: A fatal error occurred during the uninstall"
            }
            elseif (($? -eq $True) -and ($result -eq 1618)) {
                Write-Host "Error 1618: Another uninstall process is in progress"
            }
            else {
                Write-Host "Error: Issue uninstalling $AppName Exit codes: $? and $Result"
            }
        }
    } elseif ($endapp -like '"C:\*'){
        $endapp = $endapp -replace "`"", "`'"
        Write-Host "CMD command: /C $endapp"
        Write-Host "Powershell command: Start-Process cmd.exe -ArgumentList `"/c $endapp`""
        Write-Host "[U] uninstall $AppName on $computername [M] main menu"
        $option = Read-Host " "
        if ($option -eq "u") { 
            $Result = Invoke-Command -ComputerName $computername -ArgumentList $endapp -ScriptBlock {
                Param($endapp)
                $Exitness = Start-Process cmd.exe -ArgumentList "/c $endapp" -Wait -PassThru -WindowStyle Hidden
                $Exitness.ExitCode
            }
            if (($? -eq $True) -and ($result -eq 0)) {
                Write-Host "$AppName was successfully uninstalled on $computername"
            }
            elseif (($? -eq $True) -and ($result -eq 1641)) {
                Write-Host "$AppName uninstalled successfully on $computer, but the computer needs to restart"
            }
            elseif (($? -eq $True) -and ($result -eq 1603)) {
                Write-Host "Error 1603: A fatal error occurred during the uninstall"
            }
            elseif (($? -eq $True) -and ($result -eq 1618)) {
                Write-Host "Error 1618: Another uninstall process is in progress"
            }
            else {
                Write-Host "Error: Issue uninstalling $AppName Exit codes: $? and $Result"
            }
        }
    } else {
        Write-Host "Uninstall string not found for $AppName on $computername"
        Read-Host "Press Enter to continue to main menu"
    }
}