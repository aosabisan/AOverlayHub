# AOverlay Hub - uninstaller
# Copyright (c) 2026 Aosabi 「青錆竜也」 aosabi@pm.me. All Rights Reserved. See LICENSE.txt.
#   -Silent       remove without questions (keeps your settings unless -RemoveSettings)

param([switch]$Silent, [switch]$RemoveSettings, [string]$Dir = '', [switch]$FromTemp)

$AppTitle = 'AOverlay Hub'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AOverlayHub'
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$StartMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) $AppTitle
$DesktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) "$AppTitle.lnk"
$DataDir = Join-Path $env:APPDATA $AppTitle
$PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not $Dir) { $Dir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Windows can't delete a folder while a script inside it runs, so run from a temporary copy.
if (-not $FromTemp) {
    $tmp = Join-Path $env:TEMP ('AOverlayHub-uninstall-' + [Guid]::NewGuid().ToString('N') + '.ps1')
    Copy-Item -LiteralPath $MyInvocation.MyCommand.Path -Destination $tmp -Force
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-STA', '-File', "`"$tmp`"", '-FromTemp', '-Dir', "`"$Dir`"")
    if ($Silent) { $a += '-Silent' }
    if ($RemoveSettings) { $a += '-RemoveSettings' }
    if ($Silent) { Start-Process -FilePath $PowerShellExe -ArgumentList $a -WindowStyle Hidden -Wait } else { Start-Process -FilePath $PowerShellExe -ArgumentList $a -WindowStyle Hidden }
    exit
}

if (-not $Silent) {
    Add-Type -AssemblyName System.Windows.Forms
    $r = [Windows.Forms.MessageBox]::Show("Remove AOverlay Hub from this computer?", $AppTitle, 'YesNo', 'Question')
    if ($r -ne 'Yes') { Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue; exit }
    $r2 = [Windows.Forms.MessageBox]::Show("Also delete your AOverlay Hub settings (your overlays, links and supporter list)?`n`nChoose No to keep them in case you install it again.", $AppTitle, 'YesNo', 'Question', 'Button2')
    $RemoveSettings = ($r2 -eq 'Yes')
}

# Stop the helper if it's running.
$portFile = Join-Path $DataDir 'port.txt'
if (Test-Path -LiteralPath $portFile) {
    try {
        $p = (Get-Content -LiteralPath $portFile -Raw).Trim()
        $q = [Net.HttpWebRequest]::Create("http://localhost:$p/api/quit"); $q.Method = 'POST'; $q.Timeout = 2000
        $q.Headers['X-AOH'] = '1'; $q.ContentType = 'application/json'; $q.ContentLength = 2
        $s = $q.GetRequestStream(); $s.Write([byte[]](123, 125), 0, 2); $s.Close(); $q.GetResponse().Close()
    } catch {}
}
$hubPath = Join-Path $Dir 'Hub.ps1'
for ($i = 0; $i -lt 20; $i++) {
    $procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($hubPath, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if (-not $procs.Count) { break }
    if ($i -eq 10) { $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } }
    Start-Sleep -Milliseconds 300
}

Remove-ItemProperty -Path $RunKey -Name 'AOverlayHub' -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $StartMenuDir) { Remove-Item -LiteralPath $StartMenuDir -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path -LiteralPath $DesktopLink) { Remove-Item -LiteralPath $DesktopLink -Force -ErrorAction SilentlyContinue }
Remove-Item -Path $UninstallKey -Recurse -Force -ErrorAction SilentlyContinue

# Only remove the install folder if it really is AOverlay Hub's.
if ((Test-Path -LiteralPath $hubPath) -and (Test-Path -LiteralPath (Join-Path $Dir 'web\stage.html'))) {
    Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($RemoveSettings -and (Test-Path -LiteralPath $DataDir)) { Remove-Item -LiteralPath $DataDir -Recurse -Force -ErrorAction SilentlyContinue }

if (-not $Silent) {
    $msg = "AOverlay Hub has been removed."
    if (-not $RemoveSettings) { $msg += "`n`nYour settings were kept in:`n$DataDir" }
    $msg += "`n`nThe `"AOverlay Hub`" scene in OBS was left as it is. Delete it in OBS if you don't need it any more."
    [void][Windows.Forms.MessageBox]::Show($msg, $AppTitle, 'OK', 'Information')
}
Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
