#This Script installs all applications at the same time for NIPR SDC Deployments
#wipe all text from the powershell window
cls
Add-Type -AssemblyName PresentationFramework
#set variable to path of all the apps on WDS server
$applicationfolderpath = "\\131.35.200.124\112409\Applications"
#if the path cannot be reached try connecting to the WDS and ask for credentials, repeat until the folder can be reached
if (!(Test-Path $applicationfolderpath)){
    do {
        Remove-PSDrive -Name "Z" > $null -ErrorAction SilentlyContinue
        New-PSDrive -name "Z" -PSProvider FileSystem -Root "\\131.35.200.124\112409" -Credential Get-Credential -Persist > $null
    } until (Test-Path $applicationfolderpath)
}
$credential = Import-Clixml -Path "\\131.35.200.124\112409\credential.xml"
#get list of the names of application folders in specified directory and filter for NIPR or NIPR and SIPR apps
$applications = gci $applicationfolderpath -Directory -Name | Where-Object {$_ -like "*NIPR*" -or $_ -like "*NIPR and SIPR*"}
#if that one folder is not there create it
if (!(Test-Path "C:\temp\SDC Apps")){
    md "C:\temp\SDC Apps" -Force > $null
}
#create array for jobs
$jobs = @()
#create array for completely installed apps
$completedinstall = @()
#perform loop to verify each and every application is fully installed before proceeding and resolve applications that were not installed as well as copy files if they are not downloaded
do {
    if (!(Test-Path $applicationfolderpath)){
        Remove-PSDrive -Name "Z" > $null -ErrorAction SilentlyContinue
        New-PSDrive -name "Z" -PSProvider FileSystem -Root "\\131.35.200.124\112409" -Credential $credential -Persist > $null
    }
    #status update
    cls
    #initially set $copyinprogress variable to 0, which will be later translated as false unless it is changed to 1 indicating that files will need to be copied
    #basically no copy operation in progress
    $copyinprogress = 0
    foreach ($application in $applications){
        if ($ran -eq 1){
            #if application is not in the list of completely installed apps write installing
            if ($completedinstall -notcontains $application){
                #check if a folder exists for application
                if (Test-Path "C:\temp\SDC Apps\$application"){
                    Write-Host "$application`: " -NoNewline
                    Write-Host "installing" -ForegroundColor Yellow
                #if folder is not there write copying files
                } else {
                    #if files need to be copied set $sopyinprogress to 1 which will be later translated to true
                    #basically a copy operation is in progress or will be in progress
                    $copyinprogress = 1
                    Write-Host "$application`: " -NoNewline
                    Write-Host "copying files" -ForegroundColor DarkYellow
                }
            #if application is in the list of completely installed apps write complete
            } else {
                Write-Host "$application`: " -NoNewline
                Write-Host "complete" -ForegroundColor Green
            }
        } else {
            Write-Host "$application`: " -NoNewline
            Write-Host "initiating" -ForegroundColor DarkYellow
        }
    }
    #if a copy file operation will be in progress or is currently in progress get adapter information that will be used later for download speed monitor
    if (($copyinprogress -eq 1) -or ($ran -ne 1)){
        #get the adapter that is currently being used by the computer, used for monitoring download speed
        $adapter = (Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" })
        #get list of all network interfaces that there are counters for and format to include just the name of the network interfaces
        $allNetIfs = (Get-Counter '\Network Interface(*)\Bytes Received/sec').CounterSamples | Select-Object -ExpandProperty Path | ForEach-Object {($_ -split '\(')[1] -replace '\)\\Bytes Received/sec',''} -ErrorAction SilentlyContinue
        #map the performance counter for the active local adapter to a variable
        $perfname = $allNetIfs | Where-Object {$_ -like "*$($adapter.InterfaceDescription)*"}
    }
    #set skiprefreshpause variable to 0, which translates to true and does not skip the pause between status refreshes unless it is set to one after a copy file operation
    $skiprefreshpause = 0
    #set done variable to one, which translates to true and breaks the loop. If even a single app is detected as not installed, this variable gets set to 0 and keeps the loop going until all apps are installed
    $done = 1
    #do all the commands once for each application in applications
    foreach ($application in $applications){
        #if the app folder is downloaded, proceed
        if ((((Get-ChildItem -Path "C:\temp\SDC Apps\$application" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB) -eq ((Get-ChildItem -Path "\\131.35.200.124\112409\Applications\$application" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB)) -or $ran -ne 1){
            #check application variable to perform app-specific functions
            if ($application -like "*USAF VPN*"){
                #check if application completed install verifications during this script
                if ($completedinstall -notcontains $application){
                    #set $done variable to 0 meaning applications sill need to be installed
                    $done = 0
                    #Perform install verifications if not previously passed
                    if (!((Test-Path "C:\Program Files (x86)\F5 VPN\f5fpclientW.exe") -and (Test-Path "C:\Users\Public\Desktop\USAF VPN Client.lnk"))){
                        #set variable to finish application installs to false
                        #check if a job has already been created
                        if ($jobs.Name -notcontains $application){
                            #if no job was created start a new job
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            #if there is a job, check it's status
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                #if job is complete, remove it and start a new one since application never got installed
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            #repeat for each application
            if ($application -like "*EITaaS Support*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!((Test-Path "C:\Program Files (x86)\EITaaS Support\EITaaS.exe") -and (Test-Path "C:\Users\Public\Desktop\EITaaS Support.lnk"))){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Cisco Secure Client*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!((test-path "C:\Program Files (x86)\Cisco\Cisco Secure Client\UI\csc_ui.exe") -and (Test-Path "C:\Users\Public\Desktop\JRSS VPN Client.lnk"))){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*BlackBerryAtHocNotifier*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!((Test-Path "C:\Program Files (x86)\BlackBerry\BlackBerry AtHoc Desktop Notifier\BlackBerryAtHocNotifier.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\BlackBerry AtHoc Desktop Notifier.lnk"))){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Microsoft 365 Apps for Enterprise*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*Microsoft 365 Apps for enterprise - en-us*"} | Select-Object DisplayName) -ne $null)){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive' -Product 'Office'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive' -Product 'Office'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Adobe Acrobat Professional DC*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!((Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Adobe Acrobat.lnk"))){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Google Chrome*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!((Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -and (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk"))){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Microsoft Edge*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!((Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk") -and (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"))){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*ActivClient*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\Program Files\HID Global\ActivClient\ac.activclient.gui.scagent.exe")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Axway Desktop Validator*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\Program Files\Tumbleweed\Desktop Validator\DVService.exe")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*DOD Trusted Certificates*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\temp\SDC Apps\$application\installfinished.txt")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                        Remove-Item "C:\temp\SDC Apps\$application\installfinished.txt"
                    }
                }
            }
            if ($application -like "*Encase Servlet*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\temp\SDC Apps\$application\installfinished.txt")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                        Remove-Item "C:\temp\SDC Apps\$application\installfinished.txt"
                    }
                }
            }
            if ($application -like "*Microsoft NetBanner*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\Program Files (x86)\Microsoft\NetBanner\NetBanner.exe")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Oracle Java*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\Program Files\Java\jre-1.8")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Tanium Client*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\Program Files (x86)\Tanium\Tanium Client")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Tenable Nessus Agent*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\Program Files\Tenable\Nessus Agent")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*DOD InstallRoot*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\Program Files (x86)\DoD-PKE\InstallRoot\InstallRootUI.exe")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                if (!(Get-Process "MSIexec" -ErrorAction SilentlyContinue)){
                                    Remove-Job $job
                                    $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                    $jobs += $job
                                }
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Microsoft Power BI*"){            
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!(Test-Path "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe")){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            if ($application -like "*Microsoft Teams*"){
                if ($completedinstall -notcontains $application){
                    $done = 0
                    if (!((gci "C:\Program Files\WindowsApps" -Directory | Where-Object {$_.Name -like "*MSTeams*"}).Name)){
                        if ($jobs.Name -notcontains $application){
                            $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                            $jobs += $job
                        } else {
                            $job = Get-Job -name $application -EA SilentlyContinue
                            if ($job.state -eq "completed"){
                                Remove-Job $job
                                $job = Start-Job -Name $application -ScriptBlock {param($application) powershell.exe -Command "& { & 'C:\temp\SDC Apps\$application\Deploy-Application.ps1' -DeployMode 'NonInteractive'; Exit $LastExitCode }" -Verb RunAs;} -ArgumentList $application
                                $jobs += $job
                            }
                        }
                    } else {
                        $completedinstall += $application
                    }
                }
            }
            $ran = 1
        #if the folder for that app is not downloaded copy the files and break the foreach loop in order to immediately refresh the status also skipping the sleep command
        } else {
            Write-Host ""
            #set cursor location to a variable to be used for copy item status display
            $statuspos = $host.UI.RawUI.CursorPosition
            #set $skiprefresh variable to 1 which will later be translated as true
            $skiprefreshpause = 1
            #set $done variable to 0, which will translate to true, keeping the loop intact until script is done installing all applications
            $done = 0
            #if a folder already exists for the application that needs to copied, delete the entire folder
            if (Test-Path "C:\temp\SDC Apps\$application"){
                Remove-Item "C:\temp\SDC Apps\$application" -Recurse
                break
            }
            #create the directory that was previously ensured to not exist and therefore will be empty
            md "C:\temp\SDC Apps\$application" > $null
            $job = Start-Job -Name "Copy $application" -ScriptBlock {param($applicationfolderpath, $application) powershell.exe -Command "Copy-Item '$applicationfolderpath\$application' 'C:\temp\SDC Apps' -Recurse"} -ArgumentList $applicationfolderpath, $application
            do {
                #get bytes received per sec for that network adapter using the counter we stored in $perfname and store the value in $rx
                $rx = (Get-Counter "\Network Interface($perfname)\Bytes Received/sec").CounterSamples.CookedValue
                #convert the bytes received per sec stored in $rx to Mb/s
                $downloadMbps = [math]::Round(($rx * 8) / 1MB, 2)
                $localsize = (Get-ChildItem -Path "C:\temp\SDC Apps\$application" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB
                $remotesize = (Get-ChildItem -Path "\\131.35.200.124\112409\Applications\$application" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB
                $percent = [math]::Round(($localsize / $remotesize) * 100)
                #set cursor position to the status refresh position
                $host.UI.RawUI.CursorPosition = $statuspos
                #clear text in the status refresh position
                Write-Host "                                                                                                                           "
                #set the position back
                $host.UI.RawUI.CursorPosition = $statuspos
                #write status
                Write-Host "copying $application`: $percent`% | $downloadMbps Mb/s" -ForegroundColor DarkYellow
            } while ($localsize -ne $remotesize)
            #set cursor position to the status refresh position
            $host.UI.RawUI.CursorPosition = $statuspos
            #clear text in the status refresh position
            Write-Host "                                                                                                                           "
            #set the position back
            $host.UI.RawUI.CursorPosition = $statuspos
            #write status
            Write-Host "copied $application`: $percent`%" -ForegroundColor Green
            sleep 1
            #when all files are copied, break the loop and start at the beginning of the main loop
            break
        }
    }
    #copy file operation will continue here after the break command
    #if skiprefreshpause is not set to one enable a pause between status refreshes (only set if a copy file operation occurred so time is not wasted and status update can happen immediately)
    if ($skiprefreshpause -ne 1){
        sleep 5
    }
#if no install checks failed then exit the loop and proceed since that means all applications are installed
} while ($done -eq 0)
Write-Host "Finished installing all applications" -ForegroundColor Green
md "C:\temp\Scripts" > $null -ErrorAction SilentlyContinue
New-Item "C:\temp\Scripts\temp.txt" > $null -ErrorAction SilentlyContinue
[System.Windows.MessageBox]::Show('Warning: computer is still running a task sequence, do not restart. Computer will restart automatically when domain join is detected. If you wish to skip domain join, close the “system properties” window and the computer will automatically restart.',"WARNING") | Out-Null