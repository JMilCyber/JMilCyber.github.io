cls
$localCFTToolversion = "1.1.5"
$allowupdates = $true
#name of software share to be used as a database for a variety of functions
$swshare = "gjkz-fs-09v"
#directory in the software share to be used for storing computers that are in shop
$computersswshare = "\\$swshare\softwareShare\Scripts\In Shop\computers"
#directory in the software share to be used for storing logs of tickets and the computers tied to them
$ticketlogswshare = "\\$swshare\SoftwareShare\Scripts\In Shop\Ticket Logs"
#directory in the software share to be used for storing names connected to DODIDs
$DODIDswshare = "\\$swshare\SoftwareShare\Scripts\In shop\DODIDs"
$inshopswshare = "\\$swshare\SoftwareShare\Scripts\In Shop"
$model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
$computername = "$env:COMPUTERNAME"
$domainname = "area52.afnoapps.usaf.mil"
$DRAserver = "VEJX-RA-011v.area52.afnoapps.usaf.mil"
$latestsoftwareversionsswshare = "\\$swshare\SoftwareShare\Scripts\In Shop\latest software versions"
$username = $env:USERNAME
#add assemblies to script instance
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName system.windows.forms
#define function for read-host without ":" after the prompt, used for "Press Enter to continue..."
function Read-HostCustom {
    param($prompt)
    write-host $prompt -NoNewline
    $Host.UI.ReadLine()
}
#define function for testing if script is running with administrator rights
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
Function ADImport{
    If(!(Get-Module -list ActiveDirectory)){
        if (Test-NetConnection www.microsoft.com -Port 443 -InformationLevel Quiet){
            [System.Windows.MessageBox]::Show("The RSAT modules are not installed. Installing modules in the background","RSAT Check") | Out-Null
            Start-Job {Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0}
            sleep 5
        } else {
            [System.Windows.MessageBox]::Show("The RSAT modules are not installed. DRAGUIN won't be able to acquire your organizations automatically.","RSAT Check") | Out-Null
            sleep 5
        }
    }
    If(!(Get-Module -list NetIQ.DRA.PowerShellExtensions)){
        [System.Windows.MessageBox]::Show("The DRA modules are not installed. You need to have the DRA modules (NetIQ.DRA.PowerShellExtensions) to use CFT Tool.","DRA Check") | Out-Null
        sleep 5
        exit
    }
}
#run wake script if script is running in an admin instance
if (Test-IsAdmin){
    Unblock-File "$PSScriptRoot\CFT Tool wake.ps1"
    gci "$PSScriptRoot\Scripts" -Recurse | Unblock-File
    $PID | Out-File "$PSScriptRoot\PID.txt"
    Start-Process powershell.exe -WindowStyle Hidden "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\CFT Tool wake.ps1`"" -Verb RunAs;
    if (!(Test-Path "C:\Program Files (x86)\NetIQ\DRA Extensions\modules\NetIQ.DRA.PowerShellExtensions")){
        & "$PSScriptRoot\Scripts\drarestextensionsinstaller.exe"
        Write-Host "DRA REST extension is not installed, complete installation using the wizard"
        while (!(Test-Path "C:\Program Files (x86)\NetIQ\DRA Extensions\modules\NetIQ.DRA.PowerShellExtensions")){
            sleep 5
        }
        cls
        Read-HostCustom -prompt "Install complete, press Enter to continue..."
    }
}
$ImagingClientsFolder = "\\131.35.200.124\Updates\Imaging Clients"
$startingpos = $host.UI.RawUI.CursorPosition
#loop status of in shop computers pulled from software share
while ($true){
    $host.UI.RawUI.CursorPosition = $startingpos
    Write-Host "loading..." -NoNewline
    #clear all input
    $host.UI.RawUI.FlushInputBuffer()
    #get current year data to filter certain variable data
    $currentyear = Get-Date -Format "yyyy"
    #determine connectivity status
    $adapter = (Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }).Name
    $LocalIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $adapter -ErrorAction SilentlyContinue).IPAddress
    $result = try{Test-ComputerSecureChannel -Server $domainname -ErrorAction SilentlyContinue}catch{$false}
    if ($result){
        if (Test-ComputerSecureChannel -Server $domainname -ErrorAction SilentlyContinue) {
            if ((Test-Connection $swshare -Count 1 -ErrorAction SilentlyContinue) -and (Test-Path $inshopswshare -ErrorAction SilentlyContinue)){
                if (Test-Path $latestsoftwareversionsswshare -ErrorAction SilentlyContinue){
                    if (Test-Path $computersswshare -ErrorAction SilentlyContinue){
                        $users = gci "$computersswshare" -ErrorAction SilentlyContinue
                    }
                    #find name for local user running this script based on DODID
                    if (!($localname)){
                        $DODIDs = gci -path "$DODIDswshare" -Filter "*.txt" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                        foreach ($DODID in $DODIDs){
                            $DODID = $DODID -replace ".txt", ""
                            if ($DODID -eq $username){
                                $localname = Get-Content "$DODIDswshare\$DODID`.txt" -ErrorAction SilentlyContinue
                            }
                        }
                    }
                    if (!(Test-Path $ImagingClientsFolder)){
                        $pass = Get-Content -Path "\\gjkz-fs-09v\SoftwareShare\Scripts\credential.txt"
                        $securepass = ConvertTo-SecureString -String $pass -AsPlainText -Force
                        $credential = New-Object System.Management.Automation.PSCredential("MDT_Admin", $securepass)
                        New-PSDrive -name "Z" -PSProvider FileSystem -Root "\\131.35.200.124\112409" -Credential $credential -Persist > $null
                        if (!(Test-Path $ImagingClientsFolder)){
                            $try = 0
                            do {
                                Remove-PSDrive -Name "Z" > $null -ErrorAction SilentlyContinue
                                New-PSDrive -name "Z" -PSProvider FileSystem -Root "\\131.35.200.124\112409" -Credential $credential -Persist > $null
                                sleep 1
                                $try++
                            } until ((Test-Path $ImagingClientsFolder) -or ($try -ge 9))
                        }
                    }	
                    #determine latest software versions
                    $latestCFTToolversion = Get-Content "$latestsoftwareversionsswshare\CFT Tool.txt"
                    $LatestAdobeVersion = Get-Content "\\gjkz-fs-09v\SoftwareShare\Scripts\In Shop\latest software versions\Adobe.txt"
                    $LatestAdobeVersion1, $LatestAdobeVersion2, $LatestAdobeVersion3, $LatestAdobeVersion4 = $LatestAdobeVersion -split "\."
                    $LatestChromeVersion = Get-Content "\\gjkz-fs-09v\SoftwareShare\Scripts\In Shop\latest software versions\Chrome.txt"
                    $LatestChromeVersion1, $LatestChromeVersion2, $LatestChromeVersion3, $LatestChromeVersion4 = $LatestChromeVersion -split "\."
                    $latestEdgeVersion = Get-Content "\\gjkz-fs-09v\SoftwareShare\Scripts\In Shop\latest software versions\Edge.txt"
                    $LatestEdgeVersion1, $LatestEdgeVersion2, $LatestEdgeVersion3, $LatestEdgeVersion4 = $LatestEdgeVersion -split "\."
                    $LatestO365Version = Get-Content "\\gjkz-fs-09v\SoftwareShare\Scripts\In Shop\latest software versions\O365.txt"
                    $LatestO365Version1, $LatestO365Version2, $LatestO365Version3, $LatestO365Version4 = $LatestO365Version -split "\."
                    $LatestDefenderVersion = Get-Content "\\gjkz-fs-09v\SoftwareShare\Scripts\In Shop\latest software versions\Defender.txt"
                    $LatestDefenderVersion1, $LatestDefenderVersion2, $LatestDefenderVersion3, $LatestDefenderVersion4 = $LatestDefenderVersion -split "\."
                    $var1 = 1
                } else {$var1 = 2}
            } else {$var1 = 3}
        } else {$var1 = 0}
    } else {$var1 = 0}
    if (!($localname)){
        $localname = $env:USERNAME
    }
    #perform background ticket updates if fully connected and running as admin
    if ((Test-IsAdmin) -and ($var1 -eq 1)){
        if ($allowupdates){
            if (($localCFTToolversion) -and ($latestCFTToolversion)){
                if ($localCFTToolversion -ne $latestCFTToolversion){
                    cls
                    Write-Host "CFT Tool requires an update: updating to $latestCFTToolversion" -ForegroundColor Yellow
                    Remove-Item $PSScriptRoot -Force -Recurse -EA SilentlyContinue
                    $scriptrootparent = Split-Path -path $PSScriptRoot
                    Write-Host "downloading files" -ForegroundColor Yellow
                    Copy-Item "\\gjkz-fs-09v\SoftwareShare\Scripts\CFT Tool" "$scriptrootparent" -Recurse -Force -EA SilentlyContinue
                    Write-Host "update complete, restarting tool" -ForegroundColor Yellow
                    sleep 3
                    Start-Process "$PSScriptRoot\CFT Tool.exe"
                    exit
                }
            }
        }
    }
    #sort logged tickets from oldest to newest
    $targetFile = "ticketdate.txt"
    $parentFolder = "$PSScriptRoot\Ticket Logs"
    $folders = gci -Path $parentFolder -Directory | ForEach-Object {
        $file = gci -Path $_.FullName -Filter $targetFile -File | Select-Object -First 1
        if ($file){
            [PSCustomObject]@{
                FolderName = $_.Name
                LastWriteTime = $file.LastWriteTime
                FolderPath = $_.FullName
            }
        }
    } | Where-Object {$_.LastWriteTime -ne $null} | Sort-Object -Property LastWriteTime
    $loggedtickets = $folders | Select-Object -ExpandProperty FolderName
    $items = $loggedtickets.Count
    $item = 0
    $loggedcomputers = [System.Collections.Generic.List[string]]::new()
    $ImagingClients = gci $ImagingClientsFolder -Directory -Name -ErrorAction SilentlyContinue
    cls
    if ($var1 -eq 1){
        $timeanddate = Get-Date -Format "MM-dd HH:mm"
        $localdate = Get-Date -Format "yyyy-MM-dd"
        if ($users -ne $null){
            write-host ""
            write-host "============================="
            write-host "=====" -NoNewline
            Write-Host " computers in shop " -ForegroundColor Green -NoNewline
            Write-Host "====="
            write-host "======== $timeanddate ========"
            write-host "============================="
            write-host ""
            $inshopcomputers = [System.Collections.Generic.List[string]]::new()
            $items = $users.Count
            $item = 0
            foreach ($user in $users){
                $item++
                $percentcomplete = ($item / $items) * 100
                Write-Progress -Activity "Updating..." -Status "in shop tickets" -PercentComplete $percentcomplete
                #get name data for current user in foreach loop
                $name = Get-Content "$PSScriptRoot\DODIDs\$user`.txt" -ErrorAction SilentlyContinue
                if ($name -eq $null){
                    $name = $user
                }
                $tickets = gci "$computersswshare\$user" -Directory -Name -ErrorAction SilentlyContinue
                foreach ($ticket in $tickets){
                    $ticketdate = Get-Content "$computersswshare\$user\$ticket\date.txt" -ErrorAction SilentlyContinue
                    $tickettime = Get-Content "$computersswshare\$user\$ticket\time.txt" -ErrorAction SilentlyContinue
                    write-host "==============================="
                    write-host "$ticket - $name" -ForegroundColor Yellow
                    write-host "last update: $ticketdate - $tickettime" -ForegroundColor Yellow
                    write-host "==============================="
                    $computers = gci "$computersswshare\$user\$ticket" -Directory -Name
                    if ($computers -ne $null){
                        $inshopcomputers += $computers
                        if (!(Test-Path "$PSScriptRoot\Ticket Logs\$ticket")){
                            md "$PSScriptRoot\Ticket Logs\$ticket" > $null
                        }
                        Remove-Item "$PSScriptRoot\Ticket Logs\$ticket\ticketdate.txt" -ErrorAction SilentlyContinue
                        Remove-Item "$PSScriptRoot\Ticket Logs\$ticket\tickettime.txt" -ErrorAction SilentlyContinue
                        $ticketdate | Out-File "$PSScriptRoot\Ticket Logs\$ticket\ticketdate.txt"
                        $tickettime | Out-File "$PSScriptRoot\Ticket Logs\$ticket\tickettime.txt"
                        foreach ($computer in $computers){
                            $computerdate = $null
                            $computerdate = Get-Content "$computersswshare\$user\$ticket\$computer\date.txt"
                            if ($computerdate -eq $localdate){
                                $computertime = ""
                                $computertime = Get-Content "$computersswshare\$user\$ticket\$computer\time.txt" -ErrorAction SilentlyContinue
                                $computerdate = $computerdate -replace "$currentyear`-", ""
                                if ($computerdate -ne $null){
                                    if ($computertime -ne $null){
                                        "- $name - last on bench: $computerdate - $computertime" | Out-File "$PSScriptRoot\Ticket Logs\$ticket\$computer`.txt" > $null
                                        write-host "$computer (online) - $name - on bench as of $computerdate - $computertime" -ForegroundColor Green
                                    } else {
                                        "- $name - last on bench: $computerdate" | Out-File "$PSScriptRoot\Ticket Logs\$ticket\$computer`.txt" > $null
                                        write-host "$computer (online) - $name - on bench as of $computerdate" -ForegroundColor Green
                                    }
                                } else {
                                    "- $name - last on bench: *unknown*" | Out-File "$PSScriptRoot\Ticket Logs\$ticket\$computer`.txt" > $null
                                    write-host "$computer (online) - $name - on bench" -ForegroundColor Green
                                }
                            }
                        }
                    } else {
                        write-host " - no computers - " -ForegroundColor Red
                    }
                    write-host ""
                }
            }
            Write-Progress -Activity "Complete" -Status "complete" -PercentComplete 100 -Completed
        } else {
            write-host ""
            write-host "============================="
            write-host "===" -NoNewline
            write-host " no computers in shop " -ForegroundColor Red -NoNewline
            write-host "===="
            write-host "======== $timeanddate ========"
            write-host "============================="
        }
        if ($ImagingClients){
            $CompletedComputerNames = @()
            write-host "--------------------------------------------------------------"
            write-host "============================="
            write-host "====" -NoNewline
            Write-Host " Completed Reimages " -ForegroundColor Green -NoNewline
            Write-Host "====="
            write-host "======== $timeanddate ========"
            write-host "============================="
            foreach ($Client in $ImagingClients){
                if ($inshopcomputers -notcontains $Client){
                    if ($Client -like "GJKZ*"){
                        $CompletedComputerNames += $Client
                        if (Test-Path "$ImagingClientsFolder\$client\done.txt"){
                            $ImagingClients = $ImagingClients | Where-Object -FilterScript {$_ -ne $Client} -ErrorAction SilentlyContinue
                            $Date = Get-Content "$ImagingClientsFolder\$client\Date.txt" -ErrorAction SilentlyContinue
                            $IPAddress = Get-Content "$ImagingClientsFolder\$client\IPAddress.txt" -ErrorAction SilentlyContinue
                            $DRA = Get-Content "$ImagingClientsFolder\$client\DRA.txt" -ErrorAction SilentlyContinue
                            $TimeFinished = $null
                            $TimeFinished = (Get-Item "$ImagingClientsFolder\$client\done.txt" -ErrorAction SilentlyContinue).LastWriteTime
                            if ($IPAddress){
                                if ($TimeFinished){
                                    if ($DRA){
                                        write-host "$Client ($IPAddress) - completed imaging at $TimeFinished" -ForegroundColor Green -NoNewline
                                        if ($DRA -ne "false"){
                                            write-host " - Added to DRA" -ForegroundColor Green
                                        } elseif ($DRA -eq "false") {
                                            Write-Host " - Not in DRA" -ForegroundColor Red
                                        }
                                    } else {
                                        write-host "$Client ($IPAddress) - completed imaging at $TimeFinished" -ForegroundColor Green -NoNewline
                                        Write-Host " - Checking DRA" -ForegroundColor Yellow
                                    }
                                } else {
                                    if ($DRA){
                                        write-host "$Client ($IPAddress) - completed imaging" -ForegroundColor Green -NoNewline
                                        if ($DRA -ne "false"){
                                            write-host " - Added to DRA" -ForegroundColor Green
                                        } elseif ($DRA -eq "false") {
                                            Write-Host " - Not in DRA" -ForegroundColor Red
                                        }
                                    } else {
                                        write-host "$Client ($IPAddress) - completed imaging" -ForegroundColor Green -NoNewline
                                        Write-Host " - Checking DRA" -ForegroundColor Yellow
                                    }
                                }
                            } elseif ($TimeFinished){
                                if ($DRA){
                                    write-host "$Client - completed imaging at $TimeFinished" -ForegroundColor Green -NoNewline
                                    if ($DRA -ne "false"){
                                        write-host " - Added to DRA" -ForegroundColor Green
                                    } elseif ($DRA -eq "false") {
                                        Write-Host " - Not in DRA" -ForegroundColor Red
                                    }
                                } else {
                                    write-host "$Client - completed imaging at $TimeFinished" -ForegroundColor Green -NoNewline
                                    Write-Host " - Checking DRA" -ForegroundColor Yellow
                                }
                            } else {
                                if ($DRA){
                                    write-host "$Client - completed imaging" -ForegroundColor Green -NoNewline
                                    if ($DRA -ne "false"){
                                        write-host " - Added to DRA" -ForegroundColor Green
                                    } elseif ($DRA -eq "false") {
                                        Write-Host " - Not in DRA" -ForegroundColor Red
                                    }
                                } else {
                                    write-host "$Client - completed imaging" -ForegroundColor Green -NoNewline
                                    Write-Host " - Checking DRA" -ForegroundColor Yellow
                                }
                            }
                        }
                    }
                } else {
                    $ImagingClients = $ImagingClients | Where-Object -FilterScript {$_ -ne $Client} -ErrorAction SilentlyContinue
                }
            }
            Write-Host ""
            if ($ImagingClients){
                write-host "============================="
                write-host "====" -NoNewline
                Write-Host " Images in progress " -ForegroundColor Green -NoNewline
                Write-Host "====="
                write-host "======== $timeanddate ========"
                write-host "============================="
                foreach ($Client in $ImagingClients){
                    if ($Client -like "GJKZ*"){
                        $ImagingClients = $ImagingClients | Where-Object -FilterScript {$_ -ne $Client} -ErrorAction SilentlyContinue
                        if (Test-Path "$ImagingClientsFolder\$client\SDCApps.txt"){
                            $ImagingClients = $ImagingClients | Where-Object -FilterScript {$_ -ne $Client} -ErrorAction SilentlyContinue
                            $IPAddress = $null
                            $TimeStarted = $null
                            $IPAddress = Get-Content "$ImagingClientsFolder\$client\IPAddress.txt" -ErrorAction SilentlyContinue
                            $TimeStarted = (Get-Item "$ImagingClientsFolder\$client\SDCApps.txt" -ErrorAction SilentlyContinue).LastWriteTime
                            $TimeStarted = $TimeStarted.ToString("HH:mm")
                            if ($IPAddress){
                                if ($TimeStarted){
                                    write-host "$Client ($IPAddress) - started installing SDC apps at $TimeStarted" -ForegroundColor Yellow
                                } else {
                                    write-host "$Client ($IPAddress) - started installing SDC apps" -ForegroundColor Yellow
                                }
                            } elseif ($TimeStarted){
                                write-host "$Client - started installing SDC apps at $TimeStarted" -ForegroundColor Yellow
                            } else {
                                write-host "$Client - started installing SDC apps" -ForegroundColor Yellow
                            }
                        }
                    }
                }
                if ($ImagingClients){
                    foreach ($Client in $ImagingClients){
                        if ($Client -notlike "GJKZ*"){
                            $name = $null
                            $name = try{((nslookup $Client 2> $null | Select-String Name | Where-Object LineNumber -eq 4).ToString() -split '\s+')[-1]}catch{}
                            if ($name){
                                $name = $name.Replace(".area52.afnoapps.usaf.mil", "")
                                $name = $name.Replace(".AREA52.AFNOAPPS.USAF.MIL", "")
                            }
                            if ($CompletedComputerNames -notcontains $name){
                                $TimeStarted = $null
                                $TimeStarted = Get-Content "$ImagingClientsFolder\$client\TimeStarted.txt" -ErrorAction SilentlyContinue
                                if ($name){
                                    if ($TimeStarted){
                                        Write-Host "$name ($Client) - started imaging$TimeStarted" -ForegroundColor Yellow
                                    } else {
                                        Write-Host "$name ($Client) - started imaging" -ForegroundColor Yellow
                                    }
                                } elseif ($TimeStarted){
                                    Write-Host "UnknownName ($Client) - started imaging$TimeStarted" -ForegroundColor Yellow
                                } else {
                                    Write-Host "UnknownName ($Client) - started imaging" -ForegroundColor Yellow
                                }
                            }
                        }
                    }
                }
            } else {
                write-host "============================="
                write-host "===" -NoNewline
                Write-Host " No Images in progress " -ForegroundColor Red -NoNewline
                Write-Host "==="
                write-host "======== $timeanddate ========"
                write-host "============================="
            }
        } else {
            write-host "--------------------------------------------------------------"
            write-host "=============================================================="
            write-host "============ " -NoNewline
            Write-Host "No Imaging Clients as of $timeanddate" -ForegroundColor Red -NoNewline
            write-host " ============"
            write-host "=============================================================="
            Write-Host ""
        }
        write-host "--------------------------------------------------------------"
        Write-Host "CFT Tool v$localCFTToolversion"
        if ($localname){
            write-host "current user: $localname"
        } else {
            write-host "current user: $username"
        }
        Write-Host "model: $model"
        write-host "local computer: " -NoNewline
        Write-Host "$computername (online) | " -ForegroundColor Green -NoNewline
        if ($LocalIP){
            Write-Host "$LocalIP" -ForegroundColor Green
        } else {
            Write-Host "no valid IP address found" -ForegroundColor Red
        }
        write-host "--------------------------------------------------------------"
    } elseif ($var1 -eq 0){
        write-host "--------------------------------------------------------------"
        Write-Host "CFT Tool v$localCFTToolversion"
        if ($localname){
            write-host "current user: $localname"
        } else {
            write-host "current user: $username"
        }
        Write-Host "model: $model"
        write-host "local computer: " -NoNewline
        Write-Host "$computername (offline) | " -ForegroundColor Red -NoNewline
        if ($LocalIP){
            Write-Host "$LocalIP" -ForegroundColor Red
        } else {
            Write-Host "no valid IP address found" -ForegroundColor Red
        }
        write-host "--------------------------------------------------------------"
    } else {
        write-host "--------------------------------------------------------------"
        Write-Host "CFT Tool v$localCFTToolversion"
        if ($localname){
            write-host "current user: $localname"
        } else {
            write-host "current user: $username"
        }
        Write-Host "model: $model"
        write-host "local computer: " -NoNewline
        Write-Host "$computername (online - degraded) | " -ForegroundColor Yellow -NoNewline
        if ($LocalIP){
            Write-Host "$LocalIP" -ForegroundColor yellow
        } else {
            Write-Host "no valid IP address found" -ForegroundColor Red
        }
        if ($var1 -eq 3){
            Write-Host "Error: could not contact database in softwareshare, if $swshare is online try inserting admin token" -ForegroundColor Red
        }
        write-host "--------------------------------------------------------------"
    }
    Write-Host "r - refresh"
    Write-Host "S - search for ticket/computer"
    if (Test-IsAdmin){
        Write-Host "Q - remove smart card"
    }
    Write-Host "d - modify DODIDs"
    Write-Host "o - run script from selection"
    if ($var1 -ne 0){
        Write-Host "g - gpupdate"
    }
    Write-Host "L - view ticket logs"
    $validkeypress = 0
    $firstloop = 1
    for ($i = 1; $i -lt 180; $i++){
        if ($var1 -eq 0){
            if ($firstloop -eq 1){
                $reconnectpos = $host.UI.RawUI.CursorPosition
                write-host "attempting to repair connection" -ForegroundColor Yellow -NoNewline
                $repairpos = $host.UI.RawUI.CursorPosition
                $firstloop = 0
            } else {
                $host.UI.RawUI.CursorPosition = $repairpos
                Write-Host "     "
                $host.UI.RawUI.CursorPosition = $repairpos
            }
            Start-Sleep -Milliseconds 500
            Write-Host "." -NoNewline -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500
            Write-Host "." -NoNewline -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500
            Write-Host "." -NoNewline -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500
            $result = try{Test-ComputerSecureChannel -Server $domainname -Repair}catch{$false}
            if ($result){
                $host.UI.RawUI.CursorPosition = $reconnectpos
                Write-Host "                                                      "
                Write-Host "Connection Restored           " -ForegroundColor Green
                Write-Host "Updating..." -ForegroundColor Yellow
            }
            if (!($result)){
                $simplerepairattempts ++
                if ($simplerepairattempts -ge 30){
                    Remove-Item "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles" -Force -ErrorAction SilentlyContinue
                    $adapter = (Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }).Name
                    if ($adapter){
                        if (($adapter -notlike "*Wi-Fi*") -or ($adapter -notlike "*WiFi*")){
                            Restart-NetAdapter $adapter
                        }
                    }
                    $simplerepairattempts = 0
                }
            } else {
                break
            }
        } else {
            $result = try{Test-ComputerSecureChannel -Server $domainname}catch{$false}
            if (!($result)){
                break
            }
        }
        if ([Console]::Keyavailable){
            $key = [Console]::ReadKey()
            $host.UI.RawUI.FlushInputBuffer()
            if ($key.key -eq "r" -or $key.key -eq "s" -or $key.key -eq "q" -or $key.key -eq "o" -or $key.key -eq "d" -or $key.key -eq "g" -or $key.key -eq "l"){
                if (($key.key -eq "q" -and (!(Test-IsAdmin))) -or ($key.key -eq "g" -and ($var1 -eq 0))){
                } else {
                    $validkeypress = 1
                    break
                }
            }
        }
        if ($i -ne 180){
            sleep 1
        }
    } 
    if ($validkeypress -eq 1){
        if ($key.key -eq "s"){
            do {
                cls
                $tickets = [System.Collections.Generic.List[string]]::new()
                $loggedcomputers = [System.Collections.Generic.List[string]]::new()
                if ($var1 -eq 1){
                    $users = Get-ChildItem -path "$computersswshare" -Directory -Name
                    $timeanddate = Get-Date -Format "MM-dd HH:mm"
                    $localdate = Get-Date -Format "yyyy-MM-dd"
                    if ($users -ne $null){
                        $inshopcomputers = [System.Collections.Generic.List[string]]::new()
                        foreach ($user in $users){
                            #get name data for current user in foreach loop
                            $tickets = gci "$computersswshare\$user" -Directory -Name -ErrorAction SilentlyContinue
                            foreach ($ticket in $tickets){
                                $computers = gci "$computersswshare\$user\$ticket" -Directory -Name
                                if ($computers -ne $null){
                                    $inshopcomputers += $computers
                                }
                            }
                        }
                    }
                }
                foreach ($ticket in $loggedtickets){
                    $computers = gci "$PSScriptRoot\Ticket Logs\$ticket" -Filter "*.txt" | Select-Object -ExpandProperty Name
                    $computers = $computers -replace ".txt", ""
                    $computers = $computers | Where-Object -FilterScript {$_ -ne "ticketdate"}
                    $computers = $computers | Where-Object -FilterScript {$_ -ne "tickettime"}
                    $loggedcomputers += $computers
                }
                $alltickets = [System.Collections.Generic.List[string]]::new()
                $alltickets += $loggedtickets
                $alltickets += $tickets
                $alltickets += $loggedcomputers
                $alltickets += $inshopcomputers
                $alltickets = $alltickets | Sort-Object -Unique
                $count = $alltickets.Count
                $message = 'Search Ticket using "filter" box ($count items)'
                $searchticket = $alltickets | Out-String -Stream | Out-GridView -Title "$message" -PassThru
                if ($loggedtickets -contains $searchticket){
                    $ticketdate = Get-Content "$PSScriptRoot\Ticket Logs\$searchticket\ticketdate.txt" -ErrorAction SilentlyContinue
                    $tickettime = Get-Content "$PSScriptRoot\Ticket Logs\$searchticket\tickettime.txt" -ErrorAction SilentlyContinue
                    write-host "=========================="
                    write-host $searchticket -ForegroundColor Yellow
                    write-host "last update: $ticketdate - $tickettime" -ForegroundColor Yellow
                    write-host "=========================="        
                    $computers = gci "$PSScriptRoot\Ticket Logs\$searchticket" -Filter "*.txt" | Select-Object -ExpandProperty Name
                    $computers = $computers -replace ".txt", ""
                    $computers = $computers | Where-Object -FilterScript {$_ -ne "ticketdate"}
                    $computers = $computers | Where-Object -FilterScript {$_ -ne "tickettime"}
                    foreach ($computer in $computers){
                        $computerinfo = Get-Content "$PSScriptRoot\Ticket Logs\$searchticket\$computer`.txt" -ErrorAction SilentlyContinue
                        Write-Host "$computer $computerinfo" -ForegroundColor Red
                    }
                    write-host ""
                    Read-HostCustom -prompt "Press Enter to continue..."
                } elseif ($tickets -contains $searchticket){
                    $users = Get-ChildItem -path "$computersswshare" -Directory -Name
                    $searchuser = $null
                    foreach ($user in $users){
                        $name = Get-Content "$PSScriptRoot\DODIDs\$user`.txt" -ErrorAction SilentlyContinue
                        if ($name -eq $null){
                            $name = $user
                        }
                        $usertickets = gci "$computersswshare\$user" -Directory -Name
                        if ($usertickets -contains $searchticket){
                            $searchuser = $user
                        }
                    }
                    $ticketdate = Get-Content "$computersswshare\$searchuser\$searchticket\date.txt" -ErrorAction SilentlyContinue
                    $tickettime = Get-Content "$computersswshare\$searchuser\$searchticket\time.txt" -ErrorAction SilentlyContinue
                    write-host "==============================="
                    write-host "$searchticket - $name" -ForegroundColor Yellow
                    write-host "last update: $ticketdate - $tickettime" -ForegroundColor Yellow
                    write-host "==============================="
                    $computers = gci "$computersswshare\$searchuser\$ticket" -Directory -Name
                    if ($computers -ne $null){
                        foreach ($computer in $computers){
                            $computerdate = $null
                            $computerdate = Get-Content "$computersswshare\$searchuser\$searchticket\$computer\date.txt"
                            if ($computerdate -eq $localdate){
                                $computertime = ""
                                $computertime = Get-Content "$computersswshare\$user\$ticket\$computer\time.txt" -ErrorAction SilentlyContinue
                                $computerdate = $computerdate -replace "$currentyear`-", ""
                                if ($computertime -ne $null){
                                    write-host "$computer (online) - $name - on bench as of $computerdate - $computertime" -ForegroundColor Green
                                } else {
                                    write-host "$computer (online) - $name - on bench as of $computerdate" -ForegroundColor Green
                                }
                            } else {
                                write-host "$computer (online) - $name - on bench" -ForegroundColor Green
                            }
                        }
                    } else {
                        write-host " - no computers - " -ForegroundColor Red
                    }
                    write-host ""
                    Read-HostCustom -prompt "Press Enter to continue..."
                } elseif ($loggedcomputers -contains $searchticket){
                    $loggedticketresults = [System.Collections.Generic.List[string]]::new()
                    foreach ($ticket in $loggedtickets){
                        if (Test-Path "$PSScriptRoot\Ticket Logs\$ticket\$searchticket`.txt"){
                            $loggedticketresults += $ticket
                        }
                    }
                    foreach ($ticket in $loggedticketresults){
                        $ticketdate = Get-Content "$PSScriptRoot\Ticket Logs\$ticket\ticketdate.txt" -ErrorAction SilentlyContinue
                        $tickettime = Get-Content "$PSScriptRoot\Ticket Logs\$ticket\tickettime.txt" -ErrorAction SilentlyContinue
                        write-host "=========================="
                        write-host $ticket -ForegroundColor Yellow
                        write-host "last update: $ticketdate - $tickettime" -ForegroundColor Yellow
                        write-host "=========================="        
                        $computers = gci "$PSScriptRoot\Ticket Logs\$ticket" -Filter "*.txt" | Select-Object -ExpandProperty Name
                        $computers = $computers -replace ".txt", ""
                        $computers = $computers | Where-Object -FilterScript {$_ -ne "ticketdate"}
                        $computers = $computers | Where-Object -FilterScript {$_ -ne "tickettime"}
                        $computerinfo = Get-Content "$PSScriptRoot\Ticket Logs\$ticket\$searchticket`.txt" -ErrorAction SilentlyContinue
                        Write-Host "$searchticket $computerinfo" -ForegroundColor Red
                        write-host ""
                    }
                    Read-HostCustom -prompt "Press Enter to continue..."
                } elseif ($inshopcomputers -contains $searchticket){
                    $users = Get-ChildItem -path "$computersswshare" -Directory -Name
                    foreach ($user in $users){
                        $name = Get-Content "$PSScriptRoot\DODIDs\$user`.txt" -ErrorAction SilentlyContinue
                        if ($name -eq $null){
                            $name = $user
                        }
                        $tickets = gci "$computersswshare\$user" -Directory -Name
                        foreach ($ticket in $tickets){
                            $computers = gci "$computersswshare\$user\$ticket" -Directory -Name
                            if ($computers -contains $searchticket){
                                break
                            }
                        }
                    }
                    $ticketdate = Get-Content "$computersswshare\$user\$ticket\date.txt" -ErrorAction SilentlyContinue
                    $tickettime = Get-Content "$computersswshare\$user\$ticket\time.txt" -ErrorAction SilentlyContinue
                    write-host "==============================="
                    write-host "$ticket - $name" -ForegroundColor Yellow
                    write-host "last update: $ticketdate - $tickettime" -ForegroundColor Yellow
                    write-host "==============================="
                            $computerdate = Get-Content "$computersswshare\$user\$ticket\$searchticket\date.txt"
                            if ($computerdate -eq $localdate){
                                $computertime = Get-Content "$computersswshare\$user\$ticket\$searchticket\time.txt" -ErrorAction SilentlyContinue
                                $computerdate = $computerdate -replace "$currentyear`-", ""
                                if ($computertime -ne $null){
                                    write-host "$computer (online) - $name - on bench as of $computerdate - $computertime" -ForegroundColor Green
                                } else {
                                    write-host "$computer (online) - $name - on bench as of $computerdate" -ForegroundColor Green
                                }
                            } else {
                                write-host "$computer (online) - $name - on bench" -ForegroundColor Green
                            }
                    write-host ""
                    Read-HostCustom -prompt "Press Enter to continue..."

                } elseif ($searchticket -ne $null) {
                    Write-Host "$searchticket not found" -ForegroundColor Red
                    sleep 5
                }
            } until ($searchticket -eq $null)
        } elseif ($key.key -eq "q" -and (Test-IsAdmin)) {
            Set-ItemProperty -Name scremoveoption -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Type STRING -Value 0
            $time = "11" 
            do {
                $time -= 1
                cls
                write-host "You may remove smart card, computer will stay on while script is running"
                write-host "Please monitor computer at all times while it is unlocked" -ForegroundColor Red    
                write-host "Settings will revert in $time"
                sleep 1
            } until ($time -eq 0)
            Set-ItemProperty -Name scremoveoption -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Type STRING -Value 1
            cls
        } elseif ($key.key -eq "o") {
            cls
            $names = gci -path "$PSScriptRoot\Scripts" -Filter "*.ps1" | Select-Object -ExpandProperty Name
            $options = @()
            foreach ($name in $names){
                $name = $name -replace ".ps1", ""
                $options += "$name"
            }
            $script = $null
            $script = $options | Out-String -Stream | Out-GridView -Title "Select tool" -PassThru
            if ($script -ne $null){
                if ($script -eq "Admin_Tool_v7.8.0"){
                    $exit = 1
                    Start-Process powershell.exe -WindowStyle Minimized "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Scripts\$script`.ps1`"" -Verb RunAs;
                } else {
                    $exit = 1
                    Start-Process powershell.exe "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Scripts\$script`.ps1`"" -Verb RunAs;
                }
            }
        } elseif ($key.key -eq "d"){
            cls
            $DODIDs = $null
            Copy-Item -Path "\\$swshare\SoftwareShare\Scripts\In Shop\DODIDs" -Destination "$PSScriptRoot" -Force -Recurse -ErrorAction SilentlyContinue
            $DODIDs = Get-ChildItem -path "$PSScriptRoot\DODIDs" -Filter "*.txt" | Select-Object -ExpandProperty Name
            $oldDODIDs = $DODIDs
            md "$PSScriptRoot\temp" -ErrorAction SilentlyContinue > $null
            Copy-Item -Path "$PSScriptRoot\DODIDs" -Destination "$PSScriptRoot\temp" -Recurse -Force
            if ($DODIDs -ne $null){
                foreach ($item in $DODIDs){
                    $tempname = Get-Content "$PSScriptRoot\DODIDs\$item"
                    $item = $item -replace "a.adw.txt", ""
                    Write-Host "$item - $tempname"
                }
            } else {
                Write-Host "No DODIDS" -ForegroundColor Red
                sleep 3
            }
            Cls
            $input1 = $null
            $input2 = $null
            do {
                do {
                    $DODIDs = Get-ChildItem -path "$PSScriptRoot\DODIDs" -Filter "*.txt" | Select-Object -ExpandProperty Name
                    foreach ($item in $DODIDs){
                        $tempname = Get-Content "$PSScriptRoot\DODIDs\$item"
                        $item = $item -replace "a.adw.txt", ""
                        Write-Host "$item - $tempname"
                    }
                    if ($input1 -eq $null){
                        $input1 = [System.Windows.MessageBox]::Show('Would you like to add or edit a DOD ID?','DODID','YesNo','Information')
                    } else {
                        $input1 = [System.Windows.MessageBox]::Show('Would you like to add or edit another DOD ID?','DODID','YesNo','Information')
                    }
                    if ($input1 -eq "yes"){
                        $newDODID = Read-Host "Input DODID to add or edit (numbers only) or C to cancel"
                        if ($newDODID -ne "C"){ 
                            if ($DODIDs -notcontains "$newDODID`A.ADW.txt"){
                                $newname = Read-Host "input last name of individual with DODID: $newDODID or C to cancel"
                                if ($newname -ne "C"){
                                    $newname | Out-File "$PSScriptRoot\DODIDs\$newDODID`A.ADW.txt"
                                    Write-Host "added DODID: $newDODID - $newname" -ForegroundColor Green
                                    sleep 3
                                    cls
                                }
                            } else {
                                $name = Get-Content "$PSScriptRoot\DODIDs\$newDODID`A.ADW.txt"
                                Write-Host "$newDODID already exists as $name" -ForegroundColor Yellow
                                sleep 3
                                $messagetext = "Would you like to modify $newDODID`?"
                                $input2 = [System.Windows.MessageBox]::Show($messagetext,'DODID','YesNo','Information')
                                if ($input2 -eq "yes"){
                                    cls
                                    $newname = Read-Host "input last name of individual with DODID: $newDODID or C to cancel"
                                    cls
                                    if ($newname -ne "C"){
                                        Remove-Item "$PSScriptRoot\DODIDs\$newDODID`A.ADW.txt"
                                        $newname | Out-File "$PSScriptRoot\DODIDs\$newDODID`A.ADW.txt"
                                        Write-Host "added DODID: $newDODID - $newname" -ForegroundColor Green
                                        sleep 3
                                        cls
                                    }
                                } else {cls}
                            }
                        } else {cls}
                    }
                } until ($input1 -eq "no")
                cls
                if ($var1 -ne 1){
                    do {
                        $DODIDs = Get-ChildItem -path "$PSScriptRoot\DODIDs" -Filter "*.txt" | Select-Object -ExpandProperty Name
                        foreach ($item in $DODIDs){
                            $tempname = Get-Content "$PSScriptRoot\DODIDs\$item"
                            $item = $item -replace "a.adw.txt", ""
                            Write-Host "$item - $tempname"
                        }
                        if ($input2 -eq $null){
                            $input2 = [System.Windows.MessageBox]::Show('Would you like to remove a DOD ID?','DODID','YesNo','Information')
                        } else {
                            $var1 = 1
                            $input2 = [System.Windows.MessageBox]::Show('Would you like to remove another DOD ID?','DODID','YesNo','Information')
                        }
                        if ($input2 -eq "yes"){
                            $input1 = "yes"
                            $removeDODID = Read-Host "Input DODID to remove (numbers only)"
                            if ($DODIDs -contains "$removeDODID`A.ADW.txt"){
                                $name = Get-Content "$PSScriptRoot\DODIDs\$removeDODID`A.ADW.txt"
                                Remove-Item "$PSScriptRoot\DODIDs\$removeDODID`A.ADW.txt"
                                Write-Host "removed $removeDODID - $name" -ForegroundColor Green
                                sleep 3
                                cls
                            } else {
                                Write-Host "$removeDODID does not exist" -ForegroundColor Yellow
                                sleep 3
                                cls
                            }
                        }
                    } until ($input2 -eq "no")
                } else {
                    $input2 = "no"
                }
                cls
            } until ($input1 -eq "no" -and $input2 -eq "no")
            $DODIDs = Get-ChildItem -path "$PSScriptRoot\DODIDs" -Filter "*.txt" | Select-Object -ExpandProperty Name
            if ("$OldDODIDs" -ne "$DODIDs"){
                cls
                foreach ($DODID in $DODIDs){
                    $tempname = Get-Content "$PSScriptRoot\DODIDs\$DODID"
                    if ($oldDODIDs -contains $DODID){
                        $DODID = $DODID -replace "a.adw.txt", ""
                        Write-Host "$DODID - $tempname"
                    } else {
                        $DODID = $DODID -replace "a.adw.txt", ""
                        Write-Host "*added: $DODID - $tempname" -ForegroundColor Green
                    }
                }
                foreach ($DODID in $oldDODIDs){
                    if ($DODIDs -notcontains $DODID){
                        $DODID = $DODID -replace "a.adw.txt", ""
                        Write-Host "*removed: $DODID" -ForegroundColor red
                    }
                }
                if (Test-IsAdmin){
                    $input1 = [System.Windows.MessageBox]::Show('Would you like to save changes?','DODID','YesNo','Information')
                    if ($input1 -eq "yes"){
                        if (test-connection $swshare -count 1 -ErrorAction SilentlyContinue){
                            Remove-Item "\\$swshare\SoftwareShare\Scripts\In Shop\DODIDs" -Recurse -Force
                            copy-item -Path "$PSScriptRoot\DODIDs" -Destination "\\$swshare\SoftwareShare\Scripts\In Shop" -Recurse -Force
                        } else {
                            Write-Host "changes were only saved locally" -ForegroundColor Red
                            sleep 3
                        }
                    } else {
                        Remove-Item "$PSScriptRoot\DODIDs" -Recurse -Force -ErrorAction SilentlyContinue
                        Copy-Item -Path "\\$swshare\SoftwareShare\Scripts\In Shop\DODIDs" -Destination "$PSScriptRoot" -Force -Recurse -ErrorAction SilentlyContinue
                    }
                } else {
                    $input1 = [System.Windows.MessageBox]::Show('Would you like to save changes?','DODID','YesNo','Information')
                    if ($input1 -eq "no"){
                        Remove-Item "$PSScriptRoot\DODIDs" -Recurse -Force
                        Copy-Item -Path "$PSScriptRoot\Ticket Logs\DODIDs" -Destination "$PSScriptRoot" -Recurse -Force
                    }
                }
            } elseif ((Test-IsAdmin) -and (Test-Connection $swshare -Count 1 -ErrorAction SilentlyContinue)){
                Remove-Item "\\$swshare\SoftwareShare\Scripts\In Shop\DODIDs" -Recurse -Force
                copy-item -Path "$PSScriptRoot\DODIDs" -Destination "\\$swshare\SoftwareShare\Scripts\In Shop" -Recurse -Force
            }
            Remove-Item "$PSScriptRoot\temp" -Recurse -Force
        } elseif ($key.key -eq "g"){
            do {
                cls
                $gpupdatevar = Read-Host 'Gpupdate: Input remote computer name or press Enter for local (c to cancel)'
                cls
                if ($gpupdatevar -eq ""){
                    try {
                        Write-Host "local computer " -NoNewline
                        gpupdate /force
                        Write-Host "gpupdate on local computer was ran successfully" -ForegroundColor Green
                    } catch {
                        Write-Host "gpupdate failed on local computer" -ForegroundColor Red
                        sleep 3
                    }
                } elseif ($gpupdatevar -eq "c"){
                } else {
                    if (Test-Connection $gpupdatevar -Count 1 -ErrorAction SilentlyContinue){
                        Write-Host "$gpupdatevar (online) " -ForegroundColor Green -NoNewline
                        Write-Host "Updating policy..."
                        $updatepolicy = $host.UI.RawUI.CursorPosition
                        icm $gpupdatevar -ArgumentList $gpupdatevar {
                            param($gpupdatevar)
                            try {
                                gpupdate /force
                                Write-Host "gpupdate on $gpupdatevar was ran successfully" -ForegroundColor Green
                            } catch {
                                Write-Host "gpupdate failed on $gpupdatevar" -ForegroundColor Red
                            }
                        }
                        $return = $host.UI.RawUI.CursorPosition
                        $host.UI.RawUI.CursorPosition = $updatepolicy
                        Write-Host "                  "
                        $host.UI.RawUI.CursorPosition = $return
                        sleep 3
                    } else {
                        Write-Host "$gpupdatevar is offline" -ForegroundColor Red
                        sleep 3
                    }
                }
                if ($gpupdatevar -ne "c"){
                    $continue = [System.Windows.MessageBox]::Show('Would you like to run gpupdate on another computer?','gpupdate','YesNo','Information')
                }
            } until ($continue -eq "no" -or $gpupdatevar -eq "c")
        } elseif ($key.key -eq "l"){
            cls
            $host.UI.RawUI.FlushInputBuffer()
            Write-Host "View Ticket Logs"
            Write-Host "1 - view last 30 days"
            Write-Host "2 - view all time"
            Write-Host "c - cancel"
            for ($i = 1; $i -lt 100; $i++){
                if ([Console]::Keyavailable){
                    $key = [Console]::ReadKey()
                    if ($key.key -eq "D1" -or $key.key -eq "D2" -or $key.key -eq "c" -or $key.key -eq "NumPad1" -or $key.key -eq "NumPad2"){
                        break
                    }
                }
                Start-Sleep -Milliseconds 100
            }
            if ($key.key -eq "D1" -or $key.key -eq "D2" -or $key.key -eq "NumPad1" -or $key.key -eq "NumPad2"){
                cls
                $loggedtickets = $folders | Select-Object -ExpandProperty FolderName
                foreach ($ticket in $loggedtickets){
                    if ($swsharetickets -contains $ticket){
                        $loggedtickets = $loggedtickets | Where-Object -FilterScript {$_ -ne $ticket} -ErrorAction SilentlyContinue
                    }
                    if ($key.key -eq "D1" -or $key.key -eq "NumPad1"){
                        $lastModified = (Get-Item "$PSScriptRoot\Ticket Logs\$ticket\ticketdate.txt" -ErrorAction SilentlyContinue).LastWriteTime
                        $today = Get-Date
                        if ($lastModified -ne $null){
                            $daysOld = ($today - $lastModified).Days
                        } else {
                            $daysOld = 30
                        }
                        if ($daysOld -gt 30){
                            $loggedtickets = $loggedtickets | Where-Object -FilterScript {$_ -ne $ticket} -ErrorAction SilentlyContinue
                        }
                    }
                }
                $items = $loggedtickets.Count
                $item = 0
                $loggedcomputers = [System.Collections.Generic.List[string]]::new()
                foreach ($ticket in $loggedtickets){
                    $item++
                    $percentcomplete = ($item / $items) * 100
                    Write-Progress -Activity "Updating..." -Status "logged tickets" -PercentComplete $percentcomplete
                    $ticketdate = ""
                    $tickettime = ""
                    $ticketdate = Get-Content "$PSScriptRoot\Ticket Logs\$ticket\ticketdate.txt" -ErrorAction SilentlyContinue
                    $tickettime = Get-Content "$PSScriptRoot\Ticket Logs\$ticket\tickettime.txt" -ErrorAction SilentlyContinue
                    write-host "=========================="
                    write-host $ticket -ForegroundColor Yellow
                    write-host "last update: $ticketdate - $tickettime" -ForegroundColor Yellow
                    write-host "=========================="        
                    $computers = gci "$PSScriptRoot\Ticket Logs\$ticket" -Filter "*.txt" | Select-Object -ExpandProperty Name
                    $computers = $computers -replace ".txt", ""
                    $computers = $computers | Where-Object -FilterScript {$_ -ne "ticketdate"}
                    $computers = $computers | Where-Object -FilterScript {$_ -ne "tickettime"}
                    $loggedcomputers += $computers
                    foreach ($computer in $computers){
                        $computerinfo = Get-Content "$PSScriptRoot\Ticket Logs\$ticket\$computer`.txt" -ErrorAction SilentlyContinue
                        Write-Host "$computer $computerinfo" -ForegroundColor Red
                    }
                    write-host ""
                }
                Write-Progress -Activity "Complete" -Status "complete" -PercentComplete 100 -Completed
            if ($var1 -eq 1){
                    $users = Get-ChildItem -path "$computersswshare" -Directory -Name
                    $timeanddate = Get-Date -Format "MM-dd HH:mm"
                    $localdate = Get-Date -Format "yyyy-MM-dd"
                    if ($users -ne $null){
                        write-host ""
                        write-host "============================="
                        write-host "=====" -NoNewline
                        Write-Host " computers in shop " -ForegroundColor Green -NoNewline
                        Write-Host "====="
                        write-host "======== $timeanddate ========"
                        write-host "============================="
                        write-host ""
                        $inshopcomputers = [System.Collections.Generic.List[string]]::new()
                        $items = $users.Count
                        $item = 0
                        foreach ($user in $users){
                            $item++
                            $percentcomplete = ($item / $items) * 100
                            Write-Progress -Activity "Updating..." -Status "in shop tickets" -PercentComplete $percentcomplete
                            #get name data for current user in foreach loop
                            $name = Get-Content "$PSScriptRoot\DODIDs\$user`.txt" -ErrorAction SilentlyContinue
                            if ($name -eq $null){
                                $name = $user
                            }
                            $tickets = gci "$computersswshare\$user" -Directory -Name -ErrorAction SilentlyContinue
                            foreach ($ticket in $tickets){
                                $ticketdate = Get-Content "$computersswshare\$user\$ticket\date.txt" -ErrorAction SilentlyContinue
                                $tickettime = Get-Content "$computersswshare\$user\$ticket\time.txt" -ErrorAction SilentlyContinue
                                write-host "==============================="
                                write-host "$ticket - $name" -ForegroundColor Yellow
                                write-host "last update: $ticketdate - $tickettime" -ForegroundColor Yellow
                                write-host "==============================="
                                $computers = gci "$computersswshare\$user\$ticket" -Directory -Name
                                if ($computers -ne $null){
                                    $inshopcomputers += $computers
                                    if (!(Test-Path "$PSScriptRoot\Ticket Logs\$ticket")){
                                        md "$PSScriptRoot\Ticket Logs\$ticket" > $null
                                    }
                                    Remove-Item "$PSScriptRoot\Ticket Logs\$ticket\ticketdate.txt" -ErrorAction SilentlyContinue
                                    Remove-Item "$PSScriptRoot\Ticket Logs\$ticket\tickettime.txt" -ErrorAction SilentlyContinue
                                    $ticketdate | Out-File "$PSScriptRoot\Ticket Logs\$ticket\ticketdate.txt"
                                    $tickettime | Out-File "$PSScriptRoot\Ticket Logs\$ticket\tickettime.txt"
                                    foreach ($computer in $computers){
                                        $computerdate = $null
                                        $computerdate = Get-Content "$computersswshare\$user\$ticket\$computer\date.txt"
                                        if ($computerdate -eq $localdate){
                                            $computertime = ""
                                            $computertime = Get-Content "$computersswshare\$user\$ticket\$computer\time.txt" -ErrorAction SilentlyContinue
                                            $computerdate = $computerdate -replace "$currentyear`-", ""
                                            if ($computerdate -ne $null){
                                                if ($computertime -ne $null){
                                                    "- $name - last on bench: $computerdate - $computertime" | Out-File "$PSScriptRoot\Ticket Logs\$ticket\$computer`.txt" > $null
                                                    write-host "$computer (online) - $name - on bench as of $computerdate - $computertime" -ForegroundColor Green
                                                } else {
                                                    "- $name - last on bench: $computerdate" | Out-File "$PSScriptRoot\Ticket Logs\$ticket\$computer`.txt" > $null
                                                    write-host "$computer (online) - $name - on bench as of $computerdate" -ForegroundColor Green
                                                }
                                            } else {
                                                "- $name - last on bench: *unknown*" | Out-File "$PSScriptRoot\Ticket Logs\$ticket\$computer`.txt" > $null
                                                write-host "$computer (online) - $name - on bench" -ForegroundColor Green
                                            }
                                        }
                                    }
                                } else {
                                    write-host " - no computers - " -ForegroundColor Red
                                }
                                write-host ""
                            }
                        }
                        Write-Progress -Activity "Complete" -Status "complete" -PercentComplete 100 -Completed
                    } else {
                        write-host ""
                        write-host "============================="
                        write-host "===" -NoNewline
                        write-host " no computers in shop " -ForegroundColor Red -NoNewline
                        write-host "===="
                        write-host "======== $timeanddate ========"
                        write-host "============================="
                    }
                }
                Write-Host ""
                Read-HostCustom "Press Enter to continue..."
                cls
            }
        }
    }
}