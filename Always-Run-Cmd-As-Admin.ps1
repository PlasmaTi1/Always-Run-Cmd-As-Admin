# Check for Admin
function Check-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Please run this script as Administrator!" -ForegroundColor Red
        pause
        exit
    }
}

Check-Admin

# Paths and Settings
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

# Functions
function Set-UAC {
    param([string]$mode)
    if ($mode -eq "enable") {
        Set-ItemProperty -Path $regPath -Name EnableLUA -Value 1
        Set-ItemProperty -Path $regPath -Name ConsentPromptBehaviorAdmin -Value 2
        Write-Host "`nUAC Enabled with Prompt for Consent." -ForegroundColor Green
    }
    elseif ($mode -eq "disable") {
        Set-ItemProperty -Path $regPath -Name EnableLUA -Value 0
        Set-ItemProperty -Path $regPath -Name ConsentPromptBehaviorAdmin -Value 0
        Write-Host "`nUAC Completely Disabled. Always admin mode!" -ForegroundColor Yellow
    }
}

function Create-AdminShortcut {
    param(
        [string]$TargetExe,
        [string]$ShortcutPath,
        [string]$Description
    )

    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetExe
    $Shortcut.WorkingDirectory = "C:\Windows\System32"
    $Shortcut.Description = $Description
    $Shortcut.Save()

    # Set the RunAs flag in shortcut to always run as admin
    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)

    Write-Host "`nShortcut for $Description created at: $ShortcutPath" -ForegroundColor Cyan
}

function Create-AdminShortcuts {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    Create-AdminShortcut -TargetExe "C:\Windows\System32\cmd.exe" -ShortcutPath "$desktopPath\Admin CMD.lnk" -Description "Admin CMD"
    Create-AdminShortcut -TargetExe "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ShortcutPath "$desktopPath\Admin PowerShell.lnk" -Description "Admin PowerShell"
}

function Check-Status {
    $EnableLUA = Get-ItemProperty -Path $regPath -Name EnableLUA -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnableLUA
    $Consent = Get-ItemProperty -Path $regPath -Name ConsentPromptBehaviorAdmin -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ConsentPromptBehaviorAdmin

    Write-Host "`n==== Current Status ====" -ForegroundColor White
    if ($EnableLUA -eq 1) {
        Write-Host "Admin Approval Mode: ENABLED (EnableLUA = 1)" -ForegroundColor Green
    } elseif ($EnableLUA -eq 0) {
        Write-Host "Admin Approval Mode: DISABLED (EnableLUA = 0)" -ForegroundColor Yellow
    } else {
        Write-Host "Admin Approval Mode: UNKNOWN ($EnableLUA)" -ForegroundColor Red
    }

    switch ($Consent) {
        0 { Write-Host "Consent Prompt Behavior: Automatically deny elevation requests (0)" -ForegroundColor Yellow }
        1 { Write-Host "Consent Prompt Behavior: Prompt for credentials on secure desktop (1)" -ForegroundColor Green }
        2 { Write-Host "Consent Prompt Behavior: Prompt for consent on secure desktop (2)" -ForegroundColor Green }
        5 { Write-Host "Consent Prompt Behavior: Prompt for consent for non-Windows binaries (5)" -ForegroundColor Yellow }
        default { Write-Host "Consent Prompt Behavior: Unknown or custom value ($Consent)" -ForegroundColor Red }
    }
}

# Menu
while ($true) {
    Clear-Host
    Write-Host "====== UAC and Admin CMD/PowerShell ======" -ForegroundColor Cyan
    Check-Status

    Write-Host "`n1. ENABLE UAC + Prompt for Consent"
    Write-Host "2. DISABLE UAC (Always Admin, No Prompts)"
    Write-Host "3. Create CMD and PowerShell Shortcuts (Always Run as Admin)"
    Write-Host "4. RESTART Computer"
    Write-Host "Q. QUIT"

    $choice = Read-Host "`nChoose an option"

    switch ($choice) {
        "1" {
            Set-UAC -mode "enable"
            pause
        }
        "2" {
            Set-UAC -mode "disable"
            pause
        }
        "3" {
            Create-AdminShortcuts
            pause
        }
        "4" {
            Write-Host "Restarting computer..." -ForegroundColor Magenta
            Restart-Computer -Force
        }
        "Q" { break }
        "q" { break }
        default {
            Write-Host "Invalid choice!" -ForegroundColor Red
            pause
        }
    }
}

