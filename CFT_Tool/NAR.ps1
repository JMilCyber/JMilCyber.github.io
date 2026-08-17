cls
function Read-HostCustom {
    param($prompt)
    write-host $prompt -NoNewline
    $Host.UI.ReadLine()
}
function Clear-BrowserCache {
    Param(
        [Switch]$Chrome,
        [Switch]$Edge,
        [Switch]$ForceCloseBrowsers
    )
    $Usernames = gci C:\users -Directory -Name
    $loggedinusername = Get-CimInstance -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName [4]
    $loggedinusername = $loggedinusername -replace [regex]::Escape("AREA52\"), ""
    foreach ($Username in $Usernames) {
        if ($Chrome) {
            if (Get-Process -Name chrome -ErrorAction SilentlyContinue) {
                if ($ForceCloseBrowsers) {
                    if ($Username -eq $loggedinusername){
                        Write-Host "Closing Google Chrome processes for $Username as requested" -ForegroundColor Yellow
                        Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue
                    }
                } else {
                    Write-Warning "Running Google Chrome processes detected.  Use -ForceCloseBrowsers to close them automatically."
                }
            }
            $chromeCachePath = "C:\Users\$Username\AppData\Local\Google\Chrome\User Data\Default\Cache"
            if (Test-Path $chromeCachePath) {
                Write-Host "Clearing Google Chrome's browser cache for $Username" -ForegroundColor Green
                Remove-Item -Path $chromeCachePath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        if ($Edge) {
            if (Get-Process -Name msedge -ErrorAction SilentlyContinue) {
                if ($ForceCloseBrowsers) {
                    if ($Username -eq $loggedinusername){
                        Write-Host "Closing Microsoft Edge processes for $Username as requested" -ForegroundColor Yellow
                        Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
                    }
                } else {
                    Write-Warning "Running Microsoft Edge processes detected. Use -ForceCloseBrowsers to close them automatically."
                }
            }
            $edgeCachePath = "C:\Users\$Username\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
            if (Test-Path $edgeCachePath) {
                Write-Host "Clearing Microsoft Edge's browser cache for $Username" -ForegroundColor Green
                Remove-Item -Path $edgeCachePath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
Read-HostCustom -prompt "Press Enter to clear all browser cache and force close browsers..."
Clear-BrowserCache -Chrome -Edge
ipconfig /flushdns
nbtstat -R
nbtstat -RR
netsh int ip reset
netsh winsock reset
netsh interface tcp set global autotuninglevel=disabled
$adapter = (Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }).Name
Disable-NetAdapter -Name $adapter
Write-Host "resetting network adapter... please wait" -ForegroundColor Yellow
sleep 5
Enable-NetAdapter -Name $adapter
Write-Host "done" -ForegroundColor Green
sleep 3
ipconfig
Read-HostCustom "Press Enter to exit..."
exit