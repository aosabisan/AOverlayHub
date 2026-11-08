# AOverlay Hub - installer
# Copyright (c) 2026 Aosabi 「青錆竜也」 aosabi@pm.me. All Rights Reserved. See LICENSE.txt.
#
# Installs for the current Windows user only (no admin rights needed).
#   -Silent           install without the window (uses the options below)
#   -InstallDir <p>   where to install (default: %LOCALAPPDATA%\Programs\AOverlay Hub)
#   -NoDesktop -NoAutostart -NoLaunch

param([switch]$Silent, [string]$InstallDir = '', [switch]$NoDesktop, [switch]$NoAutostart, [switch]$NoLaunch)

$ErrorActionPreference = 'Stop'
$AppTitle = 'AOverlay Hub'
$AppVersion = '1.1.1'
$Publisher = 'Aosabi 「青錆竜也」'
$Credit = 'Made and distributed by Aosabi 「青錆竜也」  aosabi@pm.me'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceApp = Join-Path $Here 'app'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AOverlayHub'
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
# One Start menu folder, "AOverlay", with one launcher, "AOverlay" (the control panel, which also has the music settings).
$Launcher = 'AOverlay'
$StartMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) $Launcher
$DesktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) "$Launcher.lnk"
# What version 1.1.0 and older made, replaced by the above.
$OldStartMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) $AppTitle
$OldDesktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) "$AppTitle.lnk"
$PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$DataDir = Join-Path $env:APPDATA $AppTitle

$existing = $null
try { $existing = (Get-ItemProperty -Path $UninstallKey -ErrorAction Stop).InstallLocation } catch {}
if (-not $InstallDir) { if ($existing) { $InstallDir = $existing } else { $InstallDir = Join-Path $env:LOCALAPPDATA ('Programs\' + $AppTitle) } }

function Stop-Hub([string]$dir) {
    # Ask a running copy to quit, then make sure it has.
    $portFile = Join-Path $DataDir 'port.txt'
    if (Test-Path -LiteralPath $portFile) {
        try {
            $p = (Get-Content -LiteralPath $portFile -Raw).Trim()
            $r = [Net.HttpWebRequest]::Create("http://localhost:$p/api/quit"); $r.Method = 'POST'; $r.Timeout = 2000
            $r.Headers['X-AOH'] = '1'; $r.ContentType = 'application/json'; $r.ContentLength = 2
            $s = $r.GetRequestStream(); $s.Write([byte[]](123, 125), 0, 2); $s.Close(); $r.GetResponse().Close()
        } catch {}
    }
    for ($i = 0; $i -lt 20; $i++) {
        $procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf((Join-Path $dir 'Hub.ps1'), [StringComparison]::OrdinalIgnoreCase) -ge 0 })
        if (-not $procs.Count) { return }
        if ($i -eq 10) { $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } }
        Start-Sleep -Milliseconds 300
    }
}

function New-Shortcut([string]$path, [string]$script, [string]$arguments, [string]$description, [string]$icon) {
    $ws = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($path)
    $lnk.TargetPath = $PowerShellExe
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$script`" $arguments".Trim()
    $lnk.WorkingDirectory = Split-Path -Parent $script
    $lnk.Description = $description
    $lnk.WindowStyle = 7
    if ($icon) { $lnk.IconLocation = "$icon,0" }
    $lnk.Save()
}

function Install-Hub([string]$dir, [bool]$desktop, [bool]$autostart, [bool]$launch, [scriptblock]$step) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceApp 'Hub.ps1'))) { throw "The 'app' folder is missing next to Setup.ps1. Unzip the whole download first." }
    & $step 'Closing AOverlay Hub if it is running...'
    Stop-Hub $dir
    if ($existing -and $existing -ne $dir) { Stop-Hub $existing }

    & $step 'Copying files...'
    if (Test-Path -LiteralPath $dir) {
        foreach ($old in @('Hub.ps1', 'Uninstall.ps1', 'web', 'streamerbot', 'starter-phrases.txt', 'icon.ico', 'icon.png', 'browser-connector.user.js', 'LICENSE.txt', 'README.txt', 'INSTALL.txt')) {
            $p = Join-Path $dir $old
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
        }
    }
    [void](New-Item -ItemType Directory -Force -Path $dir)
    Copy-Item -Path (Join-Path $SourceApp '*') -Destination $dir -Recurse -Force
    foreach ($f in @('LICENSE.txt', 'README.txt')) { $p = Join-Path $Here $f; if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $dir -Force } }
    Get-ChildItem -LiteralPath $dir -Recurse -File | ForEach-Object { try { Unblock-File -LiteralPath $_.FullName } catch {} }

    $hub = Join-Path $dir 'Hub.ps1'
    $ico = Join-Path $dir 'icon.ico'
    $uninst = Join-Path $dir 'Uninstall.ps1'

    & $step 'Making shortcuts...'
    # Version 1.1.0 and older used a Start menu folder and desktop shortcut called "AOverlay Hub": replace them.
    if (Test-Path -LiteralPath $OldStartMenuDir) {
        foreach ($n in @("$AppTitle.lnk", "Uninstall $AppTitle.lnk")) { Remove-Item -LiteralPath (Join-Path $OldStartMenuDir $n) -Force -ErrorAction SilentlyContinue }
        if (-not @(Get-ChildItem -LiteralPath $OldStartMenuDir -Force -ErrorAction SilentlyContinue).Count) { Remove-Item -LiteralPath $OldStartMenuDir -Force -ErrorAction SilentlyContinue }
    }
    Remove-Item -LiteralPath $OldDesktopLink -Force -ErrorAction SilentlyContinue
    [void](New-Item -ItemType Directory -Force -Path $StartMenuDir)
    New-Shortcut (Join-Path $StartMenuDir "$Launcher.lnk") $hub '' 'Open the AOverlay control panel (overlays, music, moderation)' $ico
    New-Shortcut (Join-Path $StartMenuDir "Uninstall $Launcher.lnk") $uninst '' "Remove $AppTitle" $ico
    if ($desktop) { New-Shortcut $DesktopLink $hub '' 'Open the AOverlay control panel (overlays, music, moderation)' $ico }
    elseif (Test-Path -LiteralPath $DesktopLink) { Remove-Item -LiteralPath $DesktopLink -Force }

    if ($autostart) {
        $cmd = "`"$PowerShellExe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$hub`" -Background"
        New-ItemProperty -Path $RunKey -Name 'AOverlayHub' -Value $cmd -PropertyType String -Force | Out-Null
    } else { Remove-ItemProperty -Path $RunKey -Name 'AOverlayHub' -ErrorAction SilentlyContinue }

    & $step 'Registering with Windows...'
    $size = 0
    try { $size = [int]((Get-ChildItem -LiteralPath $dir -Recurse -File | Measure-Object Length -Sum).Sum / 1KB) } catch {}
    New-Item -Path $UninstallKey -Force | Out-Null
    $props = [ordered]@{
        DisplayName = $AppTitle; DisplayVersion = $AppVersion; Publisher = $Publisher
        InstallLocation = $dir; DisplayIcon = $ico
        UninstallString = "`"$PowerShellExe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$uninst`""
        QuietUninstallString = "`"$PowerShellExe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$uninst`" -Silent"
    }
    foreach ($k in $props.Keys) { New-ItemProperty -Path $UninstallKey -Name $k -Value $props[$k] -PropertyType String -Force | Out-Null }
    foreach ($k in @('NoModify', 'NoRepair')) { New-ItemProperty -Path $UninstallKey -Name $k -Value 1 -PropertyType DWord -Force | Out-Null }
    New-ItemProperty -Path $UninstallKey -Name 'EstimatedSize' -Value $size -PropertyType DWord -Force | Out-Null

    if ($launch) {
        & $step 'Starting AOverlay Hub...'
        Start-Process -FilePath $PowerShellExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-STA', '-File', "`"$hub`"") -WindowStyle Hidden
    }
}

if ($Silent) {
    Install-Hub $InstallDir (-not $NoDesktop) (-not $NoAutostart) (-not $NoLaunch) { param($t) Write-Output $t }
    Write-Output 'Installed.'
    exit 0
}

# ------------------------------------------------------------------ the setup window
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object Windows.Forms.Form
$form.Text = "$AppTitle $AppVersion setup"
$form.ClientSize = New-Object Drawing.Size(560, 420)
$form.FormBorderStyle = 'FixedDialog'; $form.MaximizeBox = $false; $form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 9.5)
$icoFile = Join-Path $SourceApp 'icon.ico'
if (Test-Path -LiteralPath $icoFile) { $form.Icon = New-Object Drawing.Icon($icoFile) }

function Add-Ctl([string]$type, [int]$x, [int]$y, [int]$w, [int]$h) {
    $c = New-Object "Windows.Forms.$type"
    $c.Location = New-Object Drawing.Point($x, $y); $c.Size = New-Object Drawing.Size($w, $h)
    $form.Controls.Add($c); return $c
}

$pic = Add-Ctl 'PictureBox' 20 20 64 64
$pngFile = Join-Path $SourceApp 'icon.png'
if (Test-Path -LiteralPath $pngFile) { $pic.Image = [Drawing.Image]::FromFile($pngFile); $pic.SizeMode = 'Zoom' }
$title = Add-Ctl 'Label' 100 22 440 30
$title.Text = $AppTitle; $title.Font = New-Object Drawing.Font('Segoe UI', 16, [Drawing.FontStyle]::Bold)
$sub = Add-Ctl 'Label' 100 56 440 40
$sub.Text = 'All your stream overlays in one place, including Now Playing, shown in OBS through one scene with one source.'

$lblDir = Add-Ctl 'Label' 20 112 520 20; $lblDir.Text = 'Install folder:'
$txtDir = Add-Ctl 'TextBox' 20 134 420 26; $txtDir.Text = $InstallDir
$btnBrowse = Add-Ctl 'Button' 448 132 92 28; $btnBrowse.Text = 'Browse...'
$btnBrowse.Add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Choose where to install AOverlay Hub'
    if ($dlg.ShowDialog() -eq 'OK') { $txtDir.Text = Join-Path $dlg.SelectedPath $AppTitle }
})

$chkDesk = Add-Ctl 'CheckBox' 20 176 520 24; $chkDesk.Text = 'Put a shortcut on the desktop'; $chkDesk.Checked = $true
$chkAuto = Add-Ctl 'CheckBox' 20 202 520 24; $chkAuto.Text = 'Start AOverlay Hub with Windows (recommended: it must run while you stream)'; $chkAuto.Checked = $true
$chkRun = Add-Ctl 'CheckBox' 20 228 520 24; $chkRun.Text = 'Open AOverlay Hub when setup is done'; $chkRun.Checked = $true

$lic = Add-Ctl 'LinkLabel' 20 266 520 22
$lic.Text = 'By installing you agree to the license (LICENSE.txt). Read the license'
$lic.LinkArea = New-Object Windows.Forms.LinkArea(($lic.Text.Length - 16), 16)
$lic.Add_LinkClicked({ $p = Join-Path $Here 'LICENSE.txt'; if (Test-Path -LiteralPath $p) { Start-Process notepad.exe "`"$p`"" } })

$status = Add-Ctl 'Label' 20 300 520 40; $status.ForeColor = [Drawing.Color]::DimGray
if ($existing) { $status.Text = "AOverlay Hub is already installed. Installing again updates it and keeps your settings." }

$lbCredit = Add-Ctl 'Label' 20 392 520 20
$lbCredit.Text = "$AppTitle $AppVersion  -  $Credit"; $lbCredit.ForeColor = [Drawing.Color]::DimGray

$btnInstall = Add-Ctl 'Button' 336 352 100 32; $btnInstall.Text = 'Install'
$btnCancel = Add-Ctl 'Button' 444 352 96 32; $btnCancel.Text = 'Cancel'
$form.AcceptButton = $btnInstall; $form.CancelButton = $btnCancel
$btnCancel.Add_Click({ $form.Close() })

$btnInstall.Add_Click({
    $dir = $txtDir.Text.Trim()
    if (-not $dir) { [void][Windows.Forms.MessageBox]::Show('Please choose an install folder.', $AppTitle); return }
    $btnInstall.Enabled = $false; $btnCancel.Enabled = $false; $form.UseWaitCursor = $true
    try {
        Install-Hub $dir $chkDesk.Checked $chkAuto.Checked $chkRun.Checked { param($t) $status.Text = $t; $status.Refresh() }
        $form.UseWaitCursor = $false
        $msg = "AOverlay Hub is installed.`n`n"
        if ($chkRun.Checked) { $msg += "Its control panel opens in your web browser now, with a setup wizard that also sets up OBS for you.`n`n" }
        $msg += "Open it any time from the Start menu (AOverlay). It shows an icon by the clock while it's running.`n`nIt also finds the song that's playing (VLC, Spotify, Suno, SoundCloud) by itself, so you don't need any other music program."
        [void][Windows.Forms.MessageBox]::Show($msg, $AppTitle, 'OK', 'Information')
        $form.Close()
    } catch {
        $form.UseWaitCursor = $false
        $status.Text = 'Setup stopped.'
        [void][Windows.Forms.MessageBox]::Show("Setup could not finish:`n`n$($_.Exception.Message)", $AppTitle, 'OK', 'Error')
        $btnInstall.Enabled = $true; $btnCancel.Enabled = $true
    }
})

[void]$form.ShowDialog()
