do {
    try {
        Start-Process powershell.exe "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\CFT Tool.ps1`"" -Verb RunAs;
        exit
    } catch {
        Add-Type -AssemblyName PresentationFramework
        $input = [System.Windows.MessageBox]::Show('Would you like to run CFT Tool non-elevated?','error','YesNo','Error')
        if ($input -eq "yes"){
            Start-Process powershell.exe "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\CFT Tool.ps1`""
            exit
        }
    }
} while ($true)