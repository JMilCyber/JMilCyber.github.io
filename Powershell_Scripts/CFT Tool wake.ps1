$mainPID = Get-Content "$PSScriptRoot\PID.txt"
Remove-Item "$PSScriptRoot\PID.txt"
#define basic variables
$domainname = "area52.afnoapps.usaf.mil"
$DRAserver = "VEJX-RA-011v.area52.afnoapps.usaf.mil"
$swshare = "gjkz-fs-09v"
$ticketlogswshare = "\\$swshare\SoftwareShare\Scripts\In Shop\Ticket Logs"
$computersswshare = "\\$swshare\SoftwareShare\Scripts\In Shop\computers"
$ImagingClientsFolder = "\\131.35.200.124\Updates\Imaging Clients"
$WShell = New-Object -com "Wscript.Shell"
if (!(Test-Path $ImagingClientsFolder)){
    $pass = Get-Content -Path "\\gjkz-fs-09v\SoftwareShare\Scripts\credential.txt"
    $securepass = ConvertTo-SecureString -String $pass -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("MDT_Admin", $securepass)
    New-PSDrive -name "Z" -PSProvider FileSystem -Root "\\131.35.200.124\112409" -Credential $credential -Persist > $null
    if (!(Test-Path $ImagingClientsFolder)){
        $try = 0
        do {
            Remove-PSDrive -Name "Z" > $null -ErrorAction SilentlyContinue
            New-PSDrive -name "Z" -PSProvider FileSystem -Root "\\131.35.200.124\112409" -Credential Get-Credential -Persist > $null
            sleep 1
            $try++
        } until ((Test-Path $ImagingClientsFolder) -or ($try -ge 9))
    }
}
#start infinite loop
while ($true){
    $WShell.sendkeys("{F13}")
    #test connection to softwareshare
    if (Test-Connection $swshare -Count 1 -ErrorAction SilentlyContinue){
        $ImagingClients = gci $ImagingClientsFolder -Directory -Name -ErrorAction SilentlyContinue
        $localminutes = Get-Date -Format "mm"
        $localdate = Get-Date -Format "yyyy-MM-dd"
        $localtime = get-date -Format "HH:mm"
        $localtotalseconds = [math]::Floor((Get-Date).TimeOfDay.TotalSeconds)
        #recursively search for all tickets and computers and remove outdated entries
        $users = gci "$computersswshare" -Directory -Name
        $allloggedcomputers = [System.Collections.Generic.List[string]]::new()
        if (((Get-ChildItem -Path "$ticketlogswshare" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum) -ne ((Get-ChildItem -Path "$PSScriptRoot\Ticket Logs" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum)){
            $swshareloggedticketstoupdate = gci "$ticketlogswshare" -Directory -Name
            $localloggedticketstoupdate = gci "$PSScriptRoot\Ticket Logs" -Directory -Name
            $allloggedswsharetickets = $swshareloggedticketstoupdate
            $allloggedlocaltickets = $localloggedticketstoupdate
            foreach ($ticket in $allloggedswsharetickets){
                $updatevar = 0
                if ($allloggedlocaltickets -contains $ticket){
                    $swshareticketcomputers = $null
                    $localticketcomputers = $null
                    $swshareticketcomputers = gci "$ticketlogswshare\$ticket" -Name
                    $localticketcomputers = gci "$PSScriptRoot\Ticket Logs\$ticket" -Name
                    foreach ($computer in $swshareticketcomputers){
                        $allloggedcomputers += $computer
                        if ($localticketcomputers -notcontains $computer){
                            $updatevar = 1
                        }
                    }
                } else {
                    $updatevar = 1
                }
                if ($updatevar -eq 0){
                    $swshareloggedticketstoupdate = $swshareloggedticketstoupdate | Where-Object -FilterScript {$_ -ne $ticket} -ErrorAction SilentlyContinue
                }
            }
            foreach ($ticket in $allloggedlocaltickets){
                $updatevar = 0
                if ($allloggedswsharetickets -contains $ticket){
                    $swshareticketcomputers = $null
                    $localticketcomputers = $null
                    $swshareticketcomputers = gci "$ticketlogswshare\$ticket" -Name
                    $localticketcomputers = gci "$PSScriptRoot\Ticket Logs\$ticket" -Name
                    foreach ($computer in $localticketcomputers){
                        $allloggedcomputers += $computer
                        if ($swshareticketcomputers -notcontains $computer){
                            $updatevar = 1
                        }
                    }
                } else {
                    $updatevar = 1
                }
                if ($updatevar -eq 0){
                    $localloggedticketstoupdate = $localloggedticketstoupdate | Where-Object -FilterScript {$_ -ne $ticket} -ErrorAction SilentlyContinue
                }
            }
            $items = ($swshareloggedticketstoupdate.Count) + ($localloggedticketstoupdate.Count)
            $item = 0
            if (($swshareloggedticketstoupdate) -or ($localloggedticketstoupdate)){
                foreach ($ticket in $swshareloggedticketstoupdate){
                    $item++
                    $percentcomplete = ($item / $items) * 100
                    Write-Progress -Activity "Updating ticket logs..." -Status "Processing item $item of $items"  -PercentComplete $percentcomplete
                    Copy-Item -Path "$ticketlogswshare\$ticket" -Destination "$PSScriptRoot\Ticket Logs" -Recurse -Force -ErrorAction SilentlyContinue
                }
                foreach ($ticket in $localloggedticketstoupdate){
                    $item++
                    $percentcomplete = ($item / $items) * 100
                    Write-Progress -Activity "Updating ticket logs..." -Status "Processing item $item of $items"  -PercentComplete $percentcomplete
                    Copy-Item -Path "$PSScriptRoot\Ticket Logs\$ticket" -Destination "$ticketlogswshare" -Recurse -Force -ErrorAction SilentlyContinue
                }
                Write-Progress -Activity "Updating ticket logs..." -Status "Complete!"  -Completed
            }
        }
        foreach ($Client in $ImagingClients){
            if (Test-Path "$ImagingClientsFolder\$client\done.txt"){
                $TimeFinished = $null
                $TimeFinished = (Get-Item "$ImagingClientsFolder\$client\done.txt" -ErrorAction SilentlyContinue).LastWriteTime
                $TimeComparison = (Get-Date).AddDays(-7)
                if ($TimeFinished -gt $TimeComparison){
                    $result = try {ICM $Client {((Get-WmiObject Win32_ComputerSystem).PartOfDomain)} -ErrorAction SilentlyContinue}catch{}
                    if ($result -eq $null){$result = $false}
                    Write-Host "result for $Client`: $result"
                    if (!($result)){
                        $DRA = Get-DRAComputer -Identifier $Client -Domain $domainname -DRARestServer $DRAserver -ErrorAction SilentlyContinue
                        if ($DRA){
                            $DRA | Out-File "$ImagingClientsFolder\$client\DRA.txt"
                        } else {
                            "false" | Out-File "$ImagingClientsFolder\$client\DRA.txt"
                        }
                    } else {
                        Remove-Item "$ImagingClientsFolder\$client" -Force -Recurse
                    }
                } else {
                    Remove-Item "$ImagingClientsFolder\$client" -Force -Recurse
                } 
            }
        }
        foreach ($user in $users){
            $tickets = gci "$computersswshare\$user" -Directory -Name
            if ($tickets -ne $null){
                foreach ($ticket in $tickets){
                    $ticketdate = Get-Content "$computersswshare\$user\$ticket\date.txt" -Force
                    $ticketseconds = 0
                    $ticketseconds = Get-Content "$computersswshare\$user\$ticket\seconds.txt" -Force -ErrorAction SilentlyContinue
                    $ticketsecondsdif = $localtotalseconds - $ticketseconds          
                    if (($ticketdate -eq $localdate) -or ($ticketsecondsdif -gt 300)){
                        $computers = gci "$computersswshare\$user\$ticket" -Directory -Name
                        if ($computers -ne $null){
                            foreach ($computer in $computers){
                                $computerdate = Get-Content "$computersswshare\$user\$ticket\$computer\date.txt" -Force
                                $computerseconds = 0
                                $computerseconds = Get-Content "$computersswshare\$user\$ticket\$computer\seconds.txt" -Force -ErrorAction SilentlyContinue
                                $computersecondsdif = $localtotalseconds - $computerseconds
                                if (($computerdate -ne $localdate) -or ($computersecondsdif -gt 300)){
                                    Remove-Item "$computersswshare\$user\$ticket\$computer" -Force -Recurse
                                }
                            }
                        } else {
                            Remove-Item "$computersswshare\$user\$ticket" -Force -Recurse
                            Write-Host "removed: $computersswshare\$user\$ticket" -ForegroundColor Red
                            Write-Host "computers: $computers"
                        }
                    } else {
                        Remove-Item "$computersswshare\$user\$ticket" -Force -Recurse
                        Write-Host "removed: $computersswshare\$user\$ticket" -ForegroundColor Red
                        Write-Host "ticketdate: $ticketdate"
                        Write-Host "localdate: $localdate"
                        Write-Host "ticketsecondsdif: $ticketsecondsdif"
                    }
                }
            } else {
                Remove-Item "$computersswshare\$user" -Force -Recurse
                Write-Host "removed: $computersswshare\$user" -ForegroundColor Red
                Write-Host "tickets: $tickets"
            }
        }
    }
    if (Get-Process | Where-Object { $_.Id -eq $mainPID }){
        sleep 1
    } else {
        Stop-Process -Id $PID
    }
}