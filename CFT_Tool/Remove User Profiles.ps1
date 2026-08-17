$sitecode = "GJKZ"
function Read-HostCustom {
    param($prompt)
    write-host $prompt -NoNewline
    $Host.UI.ReadLine()
}
do {
    cls
    $computername = Read-Host "Please enter computer name"
    if ($computername -notlike "*$sitecode*"){
        Write-Host "Please enter a computer name with site code:$sitecode" -ForegroundColor Red
        sleep 3
    } elseif (!(Test-Connection $computername -Count 1 -EA SilentlyContinue)){
        Write-Host "$computername offline" -ForegroundColor Red
        sleep 3
    }
} until (($computername -like "*$sitecode*") -and (Test-Connection $computername -Count 1 -EA SilentlyContinue))
cls
Write-Host "$computername online" -ForegroundColor Green
sleep 3
while ($true){
    cls
    $userstokeep = [System.Collections.Generic.List[string]]::new()
    function update {
        cls
        if ($userstodelete){
            Write-Host "These users will be deleted:"
            $userstodelete | Out-String -Stream | Write-Host -ForegroundColor Red
            if ($userstokeep){
                Write-Host "These users will not be deleted:"
                $userstokeep | Out-String -Stream | Write-Host -ForegroundColor Green
            }
        } else {
            Write-Host "no users found that can be deleted"
        }
    }
    $userstodelete = gci -Path "\\$computername\C$\Users" -Directory -Name
    $defaultuserstokeep = "Administrator", "Public", "USAF_Admin"
    foreach ($defaultuser in $defaultuserstokeep){
        $userstokeep += $defaultuser
        $userstodelete = $userstodelete | Where-Object -FilterScript {$_ -ne $defaultuser} -ErrorAction SilentlyContinue
    }
    while ($usertokeep -ne ""){
        update
        Write-Host ""
        $usertokeep = Read-Host "input user to keep (input nothing to continue)"
        if ($usertokeep -ne ""){
            if ($userstodelete -contains $usertokeep){
                $userstokeep += $usertokeep
                $userstodelete = $userstodelete | Where-Object -FilterScript {$_ -ne $usertokeep} -ErrorAction SilentlyContinue
            } else {
                Write-Host "$usertokeep could not be found"
                sleep 3
            }
        }
    }
    do {
        update
        Write-Host ""
        $verificationcode = Get-Random -Minimum 1000 -Maximum 9999
        $codeinput = Read-Host "Enter $verificationcode to proceed"
    } until ($codeinput -eq $verificationcode)
    Read-HostCustom "Press Enter to remove all the red profiles listed above on $computername"
    icm $computername {
        param($users)
        foreach ($user in $users){
            try {
                $profile = Get-CimInstance Win32_UserProfile | Where-Object {$_.LocalPath -match "\\Users\\$user$"}
                if ($profile){
                    Write-Output "Removing profile for $user"
                    $profile | Remove-CimInstance -EA Continue
                } else {
                    Write-Output "No profile found for $user"
                }
            } catch {
                Write-Warning "Failed to remove $user`: $_"
            }
        }
    } -ArgumentList (,$userstodelete)
    Write-Host ""
    Write-Host "Completed removing profiles on $computername" -ForegroundColor Green
    Read-HostCustom "Press Enter to re-run this script with the same computer name"
}