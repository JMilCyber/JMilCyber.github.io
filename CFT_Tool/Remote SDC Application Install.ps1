cls
$version = "V1.0"
Write-Host "=== Remote SDC Application Install Tool $version ==="
Write-Host "Created by A1C Miller for 92d Communications Squadron"
sleep 1
#####################
### Initial setup ###
#####################
$applicationfolderpath = "\\131.35.200.124\112409\Applications"
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName system.windows.forms
function Read-HostCustom {
    param($prompt)
    write-host $prompt -NoNewline
    $Host.UI.ReadLine()
}
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
############
### main ###
############
if (Test-IsAdmin){
    while ($true) {
        cls
        Write-Host "=== Remote SDC Application Install Tool $version ==="
        $computer = Read-Host -Prompt "input computer name"
        cls
        if (Test-Connection $computer -Count 1 -ErrorAction SilentlyContinue){
            Write-Host "$computer is online" -ForegroundColor Green
            #connect to SDC App folder in the WDS server
            if (!(Test-Path $applicationfolderpath)){
                $pass = Get-Content -Path "\\gjkz-fs-09v\SoftwareShare\Scripts\credential.txt"
                $securepass = ConvertTo-SecureString -String $pass -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential("MDT_Admin", $securepass)
                New-PSDrive -name "Z" -PSProvider FileSystem -Root "\\131.35.200.124\112409" -Credential $credential -Persist > $null
                if (!(Test-Path $applicationfolderpath)){
                    do {
                        Remove-PSDrive -Name "Z" > $null -ErrorAction SilentlyContinue
                        New-PSDrive -name "Z" -PSProvider FileSystem -Root "\\131.35.200.124\112409" -Credential Get-Credential -Persist > $null
                        sleep 1
                    } until (Test-Path $applicationfolderpath)
                }
            }	
            $applications = gci $applicationfolderpath -Directory -Name | Where-Object {(($_ -like "*NIPR*") -or ($_ -like "*NIPR and SIPR*")) -and (($_ -notlike "*EITaaS Support*") -and ($_ -notlike "*Tanium Client*"))}
            $message = "Select application to install on $computer"
            do {
                $application = $applications | Out-String -Stream | Out-GridView -Title $message -PassThru
            } while (!($application))
            if (!(Test-Path -Path "\\$computer\C$\temp\Script Files\$application")){
                md "\\$computer\C$\temp\Script Files\$application" -ErrorAction SilentlyContinue > $null
            }
            if (((Get-ChildItem -Path "\\$computer\C$\temp\Script Files\$application" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum) -ne ((Get-ChildItem -Path "\\131.35.200.124\112409\Applications\$application" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum)){
                write-host "creating directory and copying files on $computer" -ForegroundColor Green
                Remove-Item -Path "\\$computer\C$\temp\Script Files\$application" -Force -Recurse -ErrorAction SilentlyContinue
                md "\\$computer\C$\temp\Script Files\$application"
                $directories = gci "\\131.35.200.124\112409\Applications\$application" -Recurse | Select-Object FullName
                $items = ($directories.Count)
                $item = 0
                foreach ($directory in $directories){
                    $item++
                    $percentcomplete = ($item / $items) * 100
                    Write-Progress -Activity "copying $application to $computer" -Status "copying item $item of $items" -PercentComplete $percentcomplete
                    $directory = $directory -replace [regex]::Escape("@{FullName=\\131.35.200.124\112409\Applications\$application"), ""
                    $directory = $directory -replace "}", ""
                    Write-Host $directory
                    if (Test-Path -Path "\\131.35.200.124\112409\Applications\$application$directory" -PathType Container){
                        md "\\$computer\C$\temp\Script Files\$application$directory" -ErrorAction SilentlyContinue
                    } elseif (Test-Path -Path "\\131.35.200.124\112409\Applications\$application$directory" -PathType Leaf) {
                        Copy-Item -Path "\\131.35.200.124\112409\Applications\$application$directory" -Destination "\\$computer\C$\temp\Script Files\$application$directory" -force -Recurse
                        Write-Host "\\$computer\C$\temp\Script Files\$application$directory"
                        Unblock-File "\\$computer\C$\temp\Script Files\$application$directory"
                    }
                }
                Write-Progress -Activity "copying files to $computer" -Status "complete" -Completed     
            } else {
                Write-Host "installation files already exist on $computer" -ForegroundColor Green
                sleep 1
                Write-Host ""            
            }	
            try {
                $installoptionpos = $host.UI.RawUI.CursorPosition
                do {
                    $host.UI.RawUI.CursorPosition = $installoptionpos
                    if (($application -notlike "*Microsoft Edge*") -and ($application -notlike "*DOD Trusted Certificates*") -and ($application -notlike "*Encase Servlet*")){
                        Write-Host $application
                        Write-Host "[I] full clean and install (will uninstall temporarily impacting functionality)" -ForegroundColor Yellow
                        Write-Host "[U] update/repair (minimal impact to functionality) " -ForegroundColor Yellow
                        $clearpos = $host.UI.RawUI.CursorPosition
                        Write-Host "                            "
                        $host.UI.RawUI.CursorPosition = $clearpos
                        $installoption = Read-HostCustom -prompt ""
                    } else {
                        Write-Host $application
                        Write-Host "Press Enter to update/repair" -NoNewline -ForegroundColor Yellow
                        $clearpos = $host.UI.RawUI.CursorPosition
                        Write-Host "                            "
                        $host.UI.RawUI.CursorPosition = $clearpos
                        Read-HostCustom -prompt ""
                        $installoption = "U"
                    }
                } until (($installoption -eq "I") -or ($installoption -eq "U"))
                if ($application -like "*Microsoft 365 Apps for Enterprise*"){
                    $shortappname = "Microsoft 365 Apps for Enterprise"
                    $productvar = $host.UI.RawUI.CursorPosition
                    do {
                        $host.UI.RawUI.CursorPosition = $productvar
                        Write-Host "                                                                                                                                                                      "
                        $host.UI.RawUI.CursorPosition = $productvar
                        Write-Host "Enter product name (Office, ProjectProfessional, VisioProfessional, ProjectOnline):" -NoNewline -ForegroundColor Yellow
                        $product = Read-HostCustom ""
                    } until (($product -eq "office") -or ($product -eq "ProjectProfessional") -or ($product -eq "VisioProfessional") -or ($product -eq "ProjectOnline") -or ($product -eq "VisioStandard"))
                }
                $proceedwithinstall = $null
                if ($installoption -eq "I"){
                    Write-Progress -Activity "cleaning $application environment on $computer" -Status "Cleaning install environment..." -PercentComplete 0
                    $uninstallvar = Icm -ComputerName $computer -ArgumentList $application, $product -ScriptBlock {
                        param($application, $product)
                        Write-Host "Cleaning up $application" -ForegroundColor Yellow
                        $uninstallvar = 0
                        function Test-Uninstall {
                            $uninstallvar = $script:uninstallvar
                            $application = $script:application
                            
                            ##############################
                            ### ! Frequently changed ! <<#
                            #### uninstall detection <<<<#
                            ##############################
                            
                            if ($uninstallvar -eq 0){
                                if ($application -like "*Microsoft 365 Apps for Enterprise*"){
                                    if ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*Microsoft 365 Apps for enterprise - en-us*"} | Select-Object DisplayName) -ne $null){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*USAF VPN*"){
                                    $shortappname = "BIG-IP"
                                    if ((Test-Path "C:\Program Files (x86)\F5 VPN\f5fpclientW.exe") -and (Test-Path "C:\Users\Public\Desktop\USAF VPN Client.lnk")){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*EITaaS Support*"){
                                    $shortappname - "EITaaS"
                                    if ((Test-Path "C:\Program Files (x86)\EITaaS Support\EITaaS.exe") -and (Test-Path "C:\Users\Public\Desktop\EITaaS Support.lnk")){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Cisco Secure Client*"){
                                    $shortappname = "Cisco Secure Client"
                                    if ((test-path "C:\Program Files (x86)\Cisco\Cisco Secure Client\UI\csc_ui.exe") -and (Test-Path "C:\Users\Public\Desktop\JRSS VPN Client.lnk")){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*BlackBerryAtHocNotifier*"){
                                    if ((Test-Path "C:\Program Files (x86)\BlackBerry\BlackBerry AtHoc Desktop Notifier\BlackBerryAtHocNotifier.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\BlackBerry AtHoc Desktop Notifier.lnk")){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Adobe Acrobat Professional DC*"){
                                    if ((Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Adobe Acrobat.lnk")){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Google Chrome*"){
                                    $shortappname = "Google Chrome"
                                    if ((Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk")){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*ActivClient*"){
                                    $shortappname = "ActivClient"
                                    if (Test-Path "C:\Program Files\HID Global\ActivClient\ac.activclient.gui.scagent.exe"){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Axway Desktop Validator*"){
                                    $shortappname = "Axway Desktop Validator"
                                    if (Test-Path "C:\Program Files\Tumbleweed\Desktop Validator\DVService.exe"){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Microsoft NetBanner*"){
                                    $shortappname = "Microsoft NetBanner"
                                    if (Test-Path "C:\Program Files (x86)\Microsoft\NetBanner\NetBanner.exe"){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Oracle Java*"){
                                    $shortappname = "Java SE Development Kit"
                                    if (Test-Path "C:\Program Files\Java\jdk-1.8"){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Tanium Client*"){
                                    $shortappname = "Tanium Client"
                                    if (Test-Path "C:\Program Files (x86)\Tanium\Tanium Client"){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Tenable Nessus Agent*"){
                                    $shortappname = "Nessus Agent"
                                    if (Test-Path "C:\Program Files\Tenable\Nessus Agent"){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*DOD InstallRoot*"){
                                    $shortappname = "InstallRoot"
                                    if ((Test-Path "C:\Program Files (x86)\DoD-PKE\InstallRoot\InstallRootUI.exe") -or (Test-Path "C:\Program Files\DoD-PKE\InstallRoot\InstallRootUI.exe")){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Microsoft Power BI*"){ 
                                    $shortappname = "Microsoft Power BI"           
                                    if (Test-Path "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                if ($application -like "*Microsoft Teams*"){
                                    if ((gci "C:\Program Files\WindowsApps" -Directory | Where-Object {$_.Name -like "*MSTeams*"}).Name){
                                        $uninstallvar = 0
                                    } else {
                                        $uninstallvar = 1
                                    }
                                }
                                $testuninstall = [PSCustomObject]@{
                                    uninstallvar = $uninstallvar
                                    shortappname = $shortappname
                                }
                                return $testuninstall
                            }
                        }

                        ##################################
                        #>> ! end frequently changed ! ###
                        ##################################

                        $testuninstall = Test-Uninstall
                        $uninstallvar = $($testuninstall.uninstallvar)
                        $shortappname = $($testuninstall.shortappname)
                        if ($uninstallvar -eq 0){
                            $iteration = 1
                            $nativeswitch = 1
                            do {
                                Write-Host "install detected " -NoNewline -ForegroundColor Red
                                if (($shortappname) -and ($nativeswitch)){
                                    Write-Host "--- attempting uninstall with native command (attempt $iteration/3)"
                                    $regapps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*$shortappname*" } | Select-Object DisplayName, installDate, UninstallString | Sort-Object DisplayName -ev systeminfoerror
                                    $uninstallstrings = @()
                                    foreach ($regapp in $regapps){
                                        $uninstallstrings += $regapp.UninstallString
                                    }
                                    if ($uninstallstrings){
                                        foreach ($uninstallstring in $uninstallstrings){
                                            if ($uninstallstring -like 'msiexec.exe*') {
                                                $String = $uninstallstring -Replace "msiexec.exe","" -Replace "/I","" -Replace "/X",""
                                                $String = $String.Trim()
                                                $UninstallSyntax = "MsiExec.exe /X $String /qn"
                                                write-host "uninstalling with command: /c $UninstallSyntax"
                                                Start-Process cmd.exe -ArgumentList "/c $UninstallSyntax" -Wait -PassThru
                                            } else {
                                                $UninstallSyntax = $uninstallstring
                                                if ($application -like "*Microsoft 365 Apps for Enterprise*"){
                                                    $UninstallSyntax = "& $UninstallSyntax DisplayLevel=False"
                                                    Write-Host "uninstalling with command: $UninstallSyntax"
                                                    Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoExit -Command $UninstallSyntax"
                                                } else {
                                                    $UninstallSyntax = "& $UninstallSyntax"
                                                    write-host "uninstalling with command: $UninstallSyntax"
                                                    Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoExit -Command $UninstallSyntax"
                                                }
                                            }
                                        }
                                    } else {
                                        $nativeswitch = $null
                                        Write-Host "native command string was not found" -ForegroundColor Yellow
                                    }
                                } else {
                                    if ($application -like "*Adobe Acrobat Professional DC*"){
                                        Write-Host "--- attempting uninstall using AdobeAcroCleaner (attempt $iteration/3)"
                                        $UninstallSyntax = "& `"C:\temp\Script Files\$application\AdobeAcroCleaner_DC2021.exe`" /silent /product=0 /installpath=`"C:\Program Files\Adobe\Acrobat DC`" /cleanlevel=1 /scanforothers=1"
                                        Write-Host "uninstalling with command: $UninstallSyntax"
                                        Start-Process -FilePath "C:\temp\Script Files\$application\AdobeAcroCleaner_DC2021.exe" -ArgumentList @(
                                            "/silent",
                                            "/product=0",
                                            '/installpath="C:\Program Files\Adobe\Acrobat DC"',
                                            "/Cleanlevel=1",
                                            "/scanforothers=1"
                                        ) -WindowStyle Minimized -Wait
                                    } else {
                                        Write-Host "--- attempting uninstall with SDC command (attempt $iteration/3)"
                                        if ($application -like "*Microsoft 365 Apps for Enterprise*") {
                                            powershell.exe -Command "& { & 'C:\temp\Script Files\$application\Deploy-Application.ps1' -DeploymentType 'Uninstall' -Product '$product'; Exit $LastExitCode }"
                                        } else {
                                            powershell.exe -Command "& { & 'C:\temp\Script Files\$application\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
                                        }
                                    }
                                }
                                $testuninstall = Test-Uninstall
                                $uninstallvar = $($testuninstall.uninstallvar)
                                $iteration++
                            } until (($uninstallvar -eq 1) -or ($iteration -gt 3))
                        }
                        $uninstallvar
                    }
                    Write-Progress -Activity "cleaning $application on $computer" -Status "Complete!" -PercentComplete 0
                    if ($uninstallvar -eq 1){
                        Write-Host "$application is uninstalled, proceeding with install" -ForegroundColor Green
                    } else {
                        Write-Host "$application is not uninstalled" -ForegroundColor Red
                        do {
                            Write-Host "[Y] proceed with install [N] don't install"
                            $proceedwithinstall = Read-Host ":"
                        } until (($proceedwithinstall -eq "y") -or ($proceedwithinstall -eq "n"))
                    }
                }
                if ($proceedwithinstall -ne "n"){
                    Write-Progress -Activity "Installing $application on $computer" -Status "Installing..." -PercentComplete 0
                    icm $computer -ArgumentList $application, $product, $computer {
                        param($application, $product, $computer)
                        Set-ExecutionPolicy Unrestricted
                        if ($application -like "*Microsoft 365 Apps for Enterprise*"){
                            powershell.exe -Command "& { & 'C:\temp\Script Files\$application\Deploy-Application.ps1' -Product '$product' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;
                        } elseif ($application -like "*Cisco Secure Client*") {
                            $MachineType = $null
                            if ($computer -like "GJKZL-*"){
                                $MachineType = "LAPTOP"
                            } elseif ($computer -like "GJKZW-*"){
                                $MachineType = "DESKTOP"
                            }
                            if ($MachineType){
                                powershell.exe -Command "& { & 'C:\temp\Script Files\$application\Deploy-Application.ps1' -MachineType $MachineType -PIVLocation 'CONUS' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;
                            }
                            if (!($MachineType)){
                                Write-Host "Install failed - computer name is an incorrect format or not based in Fairchild AFB" -ForegroundColor Red
                                sleep 3
                            }
                        } else {
                            powershell.exe -Command "& { & 'C:\temp\Script Files\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;
                        }
                        Write-Information -MessageData $LastExitCode
                    } -InformationVariable ExitCode -InformationAction SilentlyContinue
                    $ExitCode = [int]($ExitCode[-1].MessageData.ToString().Trim())
                    Write-Progress -Activity "Installing $application on $computer" -Status "Complete" -Completed
                    if ($ExitCode -eq 3010){
                        Write-Host "waiting on restart prompt"
                        $message = "Would you like to restart the remote computer? (required for exit code: 3010)"
                        $input = [System.Windows.MessageBox]::Show('Would you like to restart the remote computer? (not required but can help solve certain issues)','restart','YesNo','Information')
                        if ($input -eq "yes"){
                            write-host "now restarting..."
                            Restart-Computer -ComputerName $computer -WsmanAuthentication Kerberos -Force -Wait -For PowerShell -Timeout 1800 -Delay 2
                            Write-Host "$computer successfully restarted" -ForegroundColor Yellow
                        }
                    }
                }
                try {
                    if (((Get-ChildItem -Path "\\$computer\C$\temp\Script Files\SDC Versions" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB) -ne ((Get-ChildItem -Path "\\gjkz-fs-09v\SoftwareShare\Scripts\In Shop\latest software versions\SDC Versions" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB)){
                        Remove-Item "\\$computer\C$\temp\Script Files\SDC Versions" -Force -Recurse -ErrorAction SilentlyContinue
                        md "\\$computer\C$\temp\Script Files\SDC Versions" > $null
                        Copy-Item "\\gjkz-fs-09v\SoftwareShare\Scripts\In Shop\latest software versions\SDC Versions\*" "\\$computer\C$\temp\Script Files\SDC Versions"
                    }
                    $remoteversion, $LatestVersion, $installcomplete = icm $computer -ArgumentList $application, $computer {
                        param($application, $computer)
                        
                        #################################
                        ##### ! Frequently changed ! <<<#
                        ### version/install detection <<#
                        #################################
                        
                        # latest version data directory
                        $SDCversiondir = "C:\temp\Script Files\SDC Versions"
                        if (!(Test-Path "$SDCversiondir\*")){
                            Write-Host "latest version info was not found"
                        }
                        $installcomplete = 0
                        $remoteversion = 0
                        $LatestVersion = 0
                        $SDCversiondir = "C:\temp\Script Files\SDC Versions"
                        if ($application -like "*Microsoft 365 Apps for Enterprise*"){
                            # install detection
                            if ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*Microsoft 365 Apps for enterprise - en-us*"} | Select-Object DisplayName) -ne $null){
                                $installcomplete = 1
                                # version detection
                                $RemoteVersion = (Get-Item "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue).GetValue("VersionToReport")
                                $LatestVersion = Get-Content "$SDCversiondir\O365.txt"
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*USAF VPN*"){
                            if ((Test-Path "C:\Program Files (x86)\F5 VPN\f5fpc.exe") -and (Test-Path "C:\Users\Public\Desktop\USAF VPN Client.lnk")){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files (x86)\F5 VPN\f5fpc.exe").VersionInfo.FileVersion
                                $remoteversion = $remoteversion -replace ", ", "."
                                $LatestVersion = Get-Content "$SDCversiondir\USAFVPN.txt"
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*EITaaS Support*"){
                            if ((Test-Path "C:\Program Files (x86)\EITaaS Support\EITaaS.exe") -and (Test-Path "C:\Users\Public\Desktop\EITaaS Support.lnk")){
                                $installcomplete = 1
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Cisco Secure Client*"){
                            if ((test-path "C:\Program Files (x86)\Cisco\Cisco Secure Client\UI\csc_ui.exe") -and (Test-Path "C:\Users\Public\Desktop\JRSS VPN Client.lnk")){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files (x86)\Cisco\Cisco Secure Client\UI\csc_ui.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\Cisco.txt" -ErrorAction SilentlyContinue
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*BlackBerryAtHocNotifier*"){
                            if ((Test-Path "C:\Program Files (x86)\BlackBerry\BlackBerry AtHoc Desktop Notifier\BlackBerryAtHocNotifier.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\BlackBerry AtHoc Desktop Notifier.lnk")){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files (x86)\BlackBerry\BlackBerry AtHoc Desktop Notifier\BlackBerryAtHocNotifier.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\AtHoc.txt" -ErrorAction SilentlyContinue
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Adobe Acrobat Professional DC*"){
                            if ((Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Adobe Acrobat.lnk")){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\Adobe.txt" -ErrorAction SilentlyContinue
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Google Chrome*"){
                            if ((Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk")){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files\Google\Chrome\Application\chrome.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\Chrome.txt" -ErrorAction SilentlyContinue
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Microsoft Edge*"){
                            if ((Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk") -and (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\Edge.txt" -ErrorAction SilentlyContinue
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*ActivClient*"){
                            if (Test-Path "C:\Program Files\HID Global\ActivClient\ac.activclient.gui.scagent.exe"){
                                $remoteversion = (Get-Item "C:\Program Files\HID Global\ActivClient\ac.activclient.gui.scagent.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\ActivClient.txt" -ErrorAction SilentlyContinue
                                $installcomplete = 1
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Axway Desktop Validator*"){
                            if (Test-Path "C:\Program Files\Tumbleweed\Desktop Validator\DVService.exe"){
                                $remoteversion = (Get-Item "C:\Program Files\Tumbleweed\Desktop Validator\DVService.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\Axway.txt" -ErrorAction SilentlyContinue
                                $installcomplete = 1
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*DOD Trusted Certificates*"){
                            $installcomplete = 1
                        }
                        if ($application -like "*Encase Servlet*"){
                            $installcomplete = 1
                        }
                        if ($application -like "*Microsoft NetBanner*"){
                            if (Test-Path "C:\Program Files (x86)\Microsoft\NetBanner\NetBanner.exe"){
                                $remoteversion = (Get-Item "C:\Program Files (x86)\Microsoft\NetBanner\NetBanner.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\NetBanner.txt" -ErrorAction SilentlyContinue
                                $installcomplete = 1
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Oracle Java*"){
                            if (Test-Path "C:\Program Files\Java\jdk-1.8"){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files\Java\jdk-1.8\bin\java.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\Java.txt" -ErrorAction SilentlyContinue
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Tanium Client*"){
                            if (Test-Path "C:\Program Files (x86)\Tanium\Tanium Client"){
                                $installcomplete = 1
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Tenable Nessus Agent*"){
                            if (Test-Path "C:\Program Files\Tenable\Nessus Agent"){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files\Tenable\Nessus Agent\nessus-agent-module.exe").VersionInfo.FileVersion
                                $LatestVersion = Get-Content "$SDCversiondir\Nessus.txt" -ErrorAction SilentlyContinue
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*DOD InstallRoot*"){
                            if ((Test-Path "C:\Program Files (x86)\DoD-PKE\InstallRoot\InstallRootUI.exe") -or (Test-Path "C:\Program Files\DoD-PKE\InstallRoot\InstallRootUI.exe")){
                                $installcomplete = 1
                                $remoteversion = (Get-Item "C:\Program Files\DoD-PKE\InstallRoot\InstallRootUI.exe").VersionInfo.FileVersion
                                if (!($remoteversion)){
                                    $remoteversion = (Get-Item "C:\Program Files (x86)\DoD-PKE\InstallRoot\InstallRootUI.exe").VersionInfo.FileVersion
                                }
                                $LatestVersion = Get-Content "$SDCversiondir\InstallRoot.txt" -ErrorAction SilentlyContinue
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Microsoft Power BI*"){            
                            if (Test-Path "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"){
                                $remoteversion = (get-item "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe").versioninfo.fileversion
                                $LatestVersion = Get-Content "$SDCversiondir\PowerBI.txt"
                                $installcomplete = 1
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($application -like "*Microsoft Teams*"){
                            if ((gci "C:\Program Files\WindowsApps" -Directory | Where-Object {$_.Name -like "*MSTeams*"}).Name){
                                $teamsdirectory = ((gci "C:\Program Files\WindowsApps" -Directory | Where-Object {$_.Name -like "*MSTeams*"}).Name)
                                $remoteversion = (get-item "C:\Program Files\WindowsApps\$teamsdirectory\ms-teams.exe").versioninfo.fileversion
                                $LatestVersion = Get-Content "$SDCversiondir\Teams.txt"
                                $installcomplete = 1
                            } else {
                                $installcomplete = 0
                            }
                        }
                        if ($remoteversion -eq $null){
                            $remoteversion = 0
                        }
                        if ($LatestVersion -eq $null){
                            $LatestVersion = 0
                        }
                        if ($installcomplete -eq $null){
                            $installcomplete = 0
                        }
                        $remoteversion; $LatestVersion; $installcomplete
                    }
                    
                    ##################################
                    #>> ! end frequently changed ! ###
                    ##################################

                    if ($installcomplete -eq 1){
                        if (!(($ExitCode -eq 3010) -or ($ExitCode -eq 0))){
                            $installcomplete = 0
                            Write-Host "Install failed with exit code: $ExitCode but application exists on $computer" -ForegroundColor Red
                        } else {
                            Write-Host "Install script ran successfully with exit code: $ExitCode" -ForegroundColor Green
                        }
                    } else {
                        Write-Host "Install failed with exit code: $ExitCode" -ForegroundColor Red
                    }
                    #split both versions by the numbers in between periods
                    $RemoteVersion1, $RemoteVersion2, $RemoteVersion3, $RemoteVersion4 = $remoteversion -split '\.'
                    $LatestVersion1, $LatestVersion2, $LatestVersion3, $LatestVersion4 = $LatestVersion -split '\.'
                    #check if app is present on remote computer
                    if ($installcomplete -eq 1) {
                        if ($remoteversion){
                            if ($LatestVersion){
                                #if any of the below checks fail then the version is lower and $versionstatus will be 0 
                                #the checks are based on if the remote version is greater or equal to latest version with the beginning numbers having priority
                                $VersionStatus = 0
                                #check if first number is greater or equal to latest version
                                if ([bigint]$RemoteVersion1 -ge [bigint]$LatestVersion1){
                                    #if first number is greater and not equal then proceed, if first number is equal and second number is greater or equal then proceed
                                    if (([bigint]$RemoteVersion2 -ge [bigint]$LatestVersion2) -or ([bigint]$RemoteVersion1 -gt [bigint]$LatestVersion1)){
                                        if (($remoteversion3) -and ($LatestVersion3)){
                                            #if second number is greater and not equal then proceed, if second number is equal and third number is greater or equal then proceed
                                            if (([bigint]$RemoteVersion3 -ge [bigint]$LatestVersion3) -or ([bigint]$RemoteVersion2 -gt [bigint]$LatestVersion2)){
                                                if (($remoteversion4) -and ($LatestVersion4)){
                                                    #if third number is greater and not equal then proceed, if third number is equal and fourth number is greater or equal then proceed
                                                    if (([bigint]$RemoteVersion4 -ge [bigint]$LatestVersion4) -or ([bigint]$RemoteVersion3 -gt [bigint]$LatestVersion3)){
                                                        $VersionStatus = 1
                                                    }
                                                } else {
                                                    $VersionStatus = 1
                                                }
                                            }
                                        } else {
                                            $VersionStatus = 1
                                        }
                                    }
                                }
                                if ($VersionStatus -eq 1) {
                                    Write-Host "$application installed on $computer with correct version: $RemoteVersion" -ForegroundColor Green
                                } else {
                                    Write-Host "$application installed on $computer with an old version: $RemoteVersion (Latest SDC version: $LatestVersion)" -ForegroundColor Red
                                }
                            } else {
                                Write-Host "$application installed on $computer with version: $remoteversion " -ForegroundColor Green -NoNewline
                                Write-Host "(Latest version unknown)" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "$application installed on $computer " -ForegroundColor Green -NoNewline
                            if (!(($application -like "*DOD Trusted Certificates*") -or ($application -like "*Encase Servlet*"))){
                                Write-Host "(version unknown)" -ForegroundColor Yellow
                            } else {
                                Write-Host ""
                            }
                        }
                    } else {
                        Write-Host "$application not installed on $computer" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "a fatal error occurred during install and version check phase (installation might be complete)" -ForegroundColor Red
                }
            } catch {
                Write-Host "a fatal error occurred during installation phase" -ForegroundColor Red
            }
            Write-Host "waiting on remove install files prompt"
            $input = [System.Windows.MessageBox]::Show('Would you like to remove the install files on the remote computer?','delete install files','YesNo','Information')
            if ($input -eq "yes"){
                Write-Host "removing install files from $computer" -ForegroundColor Yellow
                Remove-Item "\\$computer\C$\temp\Script Files\$application" -Recurse -Force
                if (!(Test-Path "\\$computer\C$\temp\Script Files\$application")){
                    Write-Host "Removed install files from $computer" -ForegroundColor Green
                } else {
                    Write-Host "install files were not deleted from $computer" -ForegroundColor Red
                }
                sleep 3
            }
        } else {
            Write-Host "$computer is offline" -ForegroundColor Red
            sleep 1
        }
        Read-HostCustom -prompt "Press Enter to continue..."
    }
} else {
    Write-Host "Script must be ran with admin rights"
    sleep 5
}