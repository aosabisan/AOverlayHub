# AOverlay Hub - helper
# Copyright (c) 2026 Aosabi 「青錆竜也」 aosabi@pm.me. All Rights Reserved. See LICENSE.txt.
#
# Runs in the background (tray icon) and serves, on this computer only:
#   http://localhost:<port>/        the control panel
#   http://localhost:<port>/stage   the one page OBS shows, with every overlay in it
# Settings are kept in %APPDATA%\AOverlay Hub\settings.json
#
#   -Background   start without opening the control panel (used when starting with Windows)
#   -Port <n>     use this port instead of the saved one (default 8096)
#   -DataDir <p>  keep settings somewhere else (for testing)

param([int]$Port = 0, [switch]$Background, [string]$DataDir = '', [switch]$NoTray)

$ErrorActionPreference = 'Continue'
$AppVersion = '1.1.0'
$AppTitle = 'AOverlay Hub'
$AppCredit = 'Aosabi 「青錆竜也」'
$AppContact = 'aosabi@pm.me'
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WebDir = Join-Path $AppDir 'web'
# LICENSE.txt sits next to Hub.ps1 when installed, one folder up in the download
$LicensePath = Join-Path $AppDir 'LICENSE.txt'
if (-not (Test-Path -LiteralPath $LicensePath)) { $LicensePath = Join-Path (Split-Path -Parent $AppDir) 'LICENSE.txt' }
if (-not $DataDir) { $DataDir = Join-Path $env:APPDATA $AppTitle }
[void](New-Item -ItemType Directory -Force -Path $DataDir)
$ConfigPath     = Join-Path $DataDir 'settings.json'
$SupportPath    = Join-Path $DataDir 'support.json'
$RumbleSeenPath = Join-Path $DataDir 'rumble-seen.json'
$PortFile       = Join-Path $DataDir 'port.txt'
$LogPath        = Join-Path $DataDir 'hub.log'
$ModPath        = Join-Path $DataDir 'moderation.json'
$UploadDir      = Join-Path $DataDir 'uploads'
$Utf8 = New-Object Text.UTF8Encoding $false
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

# ------------------------------------------------------------------ helpers
function Write-Log([string]$m) {
    try {
        if ((Test-Path -LiteralPath $LogPath) -and (Get-Item -LiteralPath $LogPath).Length -gt 1MB) { Remove-Item -LiteralPath $LogPath -Force }
        [IO.File]::AppendAllText($LogPath, ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $m + "`r`n"), $Utf8)
    } catch {}
}
function Read-Text([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    try {
        $fs = New-Object IO.FileStream($p, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]'ReadWrite, Delete')
        try { $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8, $true); return $sr.ReadToEnd() } finally { $fs.Dispose() }
    } catch { return $null }
}
function Write-TextSafe([string]$p, [string]$text) {
    $tmp = $p + '.tmp'
    [IO.File]::WriteAllText($tmp, $text, $Utf8)
    if (Test-Path -LiteralPath $p) { [IO.File]::Copy($tmp, $p, $true); Remove-Item -LiteralPath $tmp -Force } else { [IO.File]::Move($tmp, $p) }
}
function Get-NowMs { return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
function Get-Json($obj, [int]$depth = 6) {
    # Always gives an array for lists, even with 0 or 1 items.
    if ($null -eq $obj) { return 'null' }
    if ($obj -is [System.Collections.IList] -and -not ($obj -is [string])) {
        if ($obj.Count -eq 0) { return '[]' }
        $parts = foreach ($x in $obj) { Get-Json $x $depth }
        return '[' + ($parts -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $obj -Depth $depth -Compress)
}
function Get-WebText([string]$url, [int]$timeoutMs = 4000) {
    $r = [Net.HttpWebRequest]::Create($url)
    $r.Timeout = $timeoutMs; $r.ReadWriteTimeout = $timeoutMs
    $r.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AOverlayHub/' + $AppVersion
    $r.Accept = 'application/json, text/plain, */*'
    $resp = $r.GetResponse()
    try { $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8); return $sr.ReadToEnd() } finally { $resp.Close() }
}
function Get-ShortHash([string]$s) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $b = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s))
    return (($b[0..7] | ForEach-Object { $_.ToString('x2') }) -join '')
}

# ------------------------------------------------------------------ one copy only
$mutex = New-Object Threading.Mutex($false, 'Local\AOverlayHub-' + (Get-ShortHash $DataDir))
if (-not $mutex.WaitOne(0)) {
    if (-not $Background) {
        $p = Read-Text $PortFile; if (-not $p) { $p = '8096' }
        Start-Process ('http://localhost:' + $p.Trim() + '/')
    }
    exit
}

# Version counters start from the clock so pages notice a restart.
$Base = [long]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) * 1000
$script:ConfigVer = $Base; $script:SupVer = $Base; $script:EvSeq = $Base

# ------------------------------------------------------------------ settings
function Import-Config {
    $t = Read-Text $ConfigPath
    $obj = $null
    if ($t) { try { $obj = ConvertFrom-Json $t } catch { $obj = $null } }
    if ($null -eq $obj) { $t = '{"schema":1,"wizardDone":false,"overlays":[]}'; $obj = ConvertFrom-Json $t }
    $script:ConfigText = $t
    $script:Config = $obj
}
Import-Config

function Get-AllOverlays {
    $all = New-Object System.Collections.ArrayList
    foreach ($p in @($script:Config.profiles)) { if ($p) { foreach ($o in @($p.overlays)) { if ($o) { [void]$all.Add($o) } } } }
    foreach ($o in @($script:Config.overlays)) { if ($o) { [void]$all.Add($o) } }   # settings from version 1.0
    return $all
}
function Get-Overlay([string]$id) {
    foreach ($o in (Get-AllOverlays)) { if ([string]$o.id -eq $id) { return $o } }
    return $null
}

# ------------------------------------------------------------------ supporters
$script:List = New-Object System.Collections.ArrayList
$script:Totals = [ordered]@{ date = (Get-Date -Format 'yyyy-MM-dd'); kicks = 0; bits = 0; subs = 0; money = [ordered]@{} }
$script:RecentSigs = @{}
$script:StreamStart = Get-NowMs

function Import-Support {
    $t = Read-Text $SupportPath
    if (-not $t) { return }
    try {
        $j = ConvertFrom-Json $t
        foreach ($e in @($j.list)) { if ($e) { [void]$script:List.Add($e) } }
        if ($j.streamStart) { $script:StreamStart = [long]$j.streamStart }
        if ($j.totals) {
            $m = [ordered]@{}
            if ($j.totals.money) { foreach ($p in $j.totals.money.PSObject.Properties) { $m[$p.Name] = [double]$p.Value } }
            $script:Totals = [ordered]@{ date = [string]$j.totals.date; kicks = [double]$j.totals.kicks; bits = [double]$j.totals.bits; subs = [double]$j.totals.subs; money = $m }
        }
    } catch { Write-Log "Could not read support.json: $($_.Exception.Message)" }
}
function Update-TotalsDay {
    $d = Get-Date -Format 'yyyy-MM-dd'
    if ($script:Totals.date -ne $d) { $script:Totals = [ordered]@{ date = $d; kicks = 0; bits = 0; subs = 0; money = [ordered]@{} } }
}
function Update-SupportJson {
    Update-TotalsDay
    $script:SupportJson = '{"list":' + (Get-Json $script:List 4) + ',"totals":' + (ConvertTo-Json -InputObject $script:Totals -Depth 4 -Compress) + ',"streamStart":' + $script:StreamStart + '}'
}
function Save-Support {
    Update-SupportJson
    try { Write-TextSafe $SupportPath $script:SupportJson } catch { Write-Log "Could not save support.json: $($_.Exception.Message)" }
    $script:SupVer++
}
function Limit-Text($v, [int]$n) { $s = [string]$v; $s = $s.Trim(); if ($s.Length -gt $n) { $s = $s.Substring(0, $n) }; return $s }

function Add-Support($e) {
    $platforms = @('kick', 'twitch', 'youtube', 'rumble', 'donation')
    $plat = Limit-Text $e.platform 12
    if ($platforms -notcontains $plat) { $plat = 'donation' }
    $name = Limit-Text $e.name 40; if (-not $name) { $name = 'Someone' }
    $amount = Limit-Text $e.amount 40
    $what = Limit-Text $e.what 40
    $kind = Limit-Text $e.kind 10; if (@('tip', 'sub', 'resub', 'gift', 'member', 'follow') -notcontains $kind) { $kind = 'tip' }
    $unit = Limit-Text $e.unit 8; if (@('kicks', 'bits', 'money', 'count') -notcontains $unit) { $unit = '' }
    $num = $null; if ($null -ne $e.num -and [string]$e.num -ne '') { try { $num = [double]$e.num } catch { $num = $null } }
    $cur = (Limit-Text $e.currency 3).ToUpper(); if ($cur -notmatch '^[A-Z]{3}$') { $cur = '' }
    $test = [bool]$e.test

    $sig = "$plat|$name|$amount|$what"
    $now = Get-NowMs
    foreach ($k in @($script:RecentSigs.Keys)) { if ($now - $script:RecentSigs[$k] -gt 3000) { $script:RecentSigs.Remove($k) } }
    if ($script:RecentSigs.ContainsKey($sig)) { return $false }
    $script:RecentSigs[$sig] = $now

    $entry = [pscustomobject][ordered]@{
        id = ('e' + $now.ToString() + (Get-Random -Maximum 9999).ToString()); t = $now
        platform = $plat; name = $name; amount = $amount; what = $what; kind = $kind
        num = $num; unit = $unit; currency = $cur; test = $test
    }
    $script:List.Insert(0, $entry)
    while ($script:List.Count -gt 200) { $script:List.RemoveAt($script:List.Count - 1) }

    Update-TotalsDay
    if (-not $test) {
        if ($unit -eq 'kicks' -and $null -ne $num) { $script:Totals.kicks += $num }
        elseif ($unit -eq 'bits' -and $null -ne $num) { $script:Totals.bits += $num }
        elseif ($unit -eq 'money' -and $null -ne $num -and $kind -eq 'tip') {
            if (-not $cur) { $cur = 'USD' }
            if ($script:Totals.money.Contains($cur)) { $script:Totals.money[$cur] += $num } else { $script:Totals.money[$cur] = $num }
        }
        if ($kind -eq 'sub' -or $kind -eq 'resub') { $script:Totals.subs += 1 }
        elseif ($kind -eq 'gift' -and $null -ne $num -and $plat -ne 'youtube') { $script:Totals.subs += $num }
    }
    Save-Support
    return $true
}
Import-Support
Update-SupportJson

# ------------------------------------------------------------------ events for the stage (tests, reloads)
$script:Events = New-Object System.Collections.ArrayList
function Add-HubEvent([string]$json) {
    $script:EvSeq++
    [void]$script:Events.Add(@{ seq = $script:EvSeq; json = $json })
    while ($script:Events.Count -gt 400) { $script:Events.RemoveAt(0) }
}

# ------------------------------------------------------------------ status from the OBS copies of the stage (one per profile)
$script:LiveStatus = 'null'
$script:LiveSeen = [long]0
$script:LiveProfiles = @{}

# ------------------------------------------------------------------ now playing
$script:MusicCache = @{}
function Get-MusicJson([string]$id) {
    $o = Get-Overlay $id
    if (-not $o -or $o.type -ne 'music') { return '{"ok":false,"error":"not found"}' }
    $s = $o.settings
    $src = [string]$s.source
    if ($src -eq 'aoverlay') {
        $p = 8095; try { $p = [int]$s.aoverlayPort } catch {}
        if ($p -lt 1 -or $p -gt 65535) { $p = 8095 }
        $key = "ao:$p"
    } elseif ($src -eq 'file') {
        $key = 'file:' + [string]$s.filePath
    } else { return '{"ok":true,"tracks":[]}' }
    $now = Get-NowMs
    $c = $script:MusicCache[$key]
    if ($c -and ($now - $c.t) -lt 900) { return $c.json }
    $json = '{"ok":true,"tracks":[]}'
    try {
        if ($src -eq 'aoverlay') {
            $j = ConvertFrom-Json (Get-WebText ("http://localhost:$p/data") 1200)
            $tracks = New-Object System.Collections.ArrayList
            foreach ($t in @($j.tracks)) { if ($t -and $t.name) { [void]$tracks.Add([ordered]@{ source = [string]$t.source; name = [string]$t.name }) } }
            $json = '{"ok":true,"tracks":' + (Get-Json $tracks 3) + '}'
        } else {
            $path = [string]$s.filePath
            $text = Read-Text $path
            if ($null -eq $text) { $json = '{"ok":false,"error":"file not found"}' }
            else {
                $line = ''
                foreach ($l in ($text -split "`r?`n")) { if ($l.Trim()) { $line = $l.Trim(); break } }
                if ($line.Length -gt 300) { $line = $line.Substring(0, 300) }
                if ($line) { $json = '{"ok":true,"tracks":[' + (ConvertTo-Json -InputObject ([ordered]@{ source = ''; name = $line }) -Compress) + ']}' }
            }
        }
    } catch {
        $json = '{"ok":false,"error":"not running"}'
    }
    $script:MusicCache[$key] = @{ t = $now; json = $json }
    return $json
}

# ------------------------------------------------------------------ Rumble (support, follows and chat)
# Official Live Stream API (checked every few seconds) for rants, subs, gifted subs, follows and chat.
# Optionally Rumble's faster live chat feed (not an official API; read-only).
$script:RumbleSeen = @{}
$script:RumbleNext = [long]0
$script:RumbleStatus = ''
$script:RumbleLiveId = ''
function Import-RumbleSeen {
    $t = Read-Text $RumbleSeenPath
    if (-not $t) { return }
    try { $j = ConvertFrom-Json $t; foreach ($p in $j.PSObject.Properties) { $script:RumbleSeen[$p.Name] = New-Object System.Collections.ArrayList(, @($p.Value)) } } catch {}
}
function Save-RumbleSeen {
    $o = [ordered]@{}
    foreach ($k in $script:RumbleSeen.Keys) { $o[$k] = @($script:RumbleSeen[$k]) }
    try { Write-TextSafe $RumbleSeenPath (ConvertTo-Json -InputObject $o -Depth 4 -Compress) } catch {}
}
Import-RumbleSeen

function Format-Usd($v) { try { return ('$' + ([double]$v).ToString('N2', [Globalization.CultureInfo]::InvariantCulture)) } catch { return '' } }
function Get-Time($s) { try { return [DateTimeOffset]::Parse([string]$s).ToUnixTimeMilliseconds() } catch { return 0 } }
function Get-RumbleSettings {
    $r = $script:Config.rumble
    if (-not $r -or -not $r.url) {
        # settings from version 1.0 kept the link on the Support Ticker (moved when the control panel is first opened)
        foreach ($o in (Get-AllOverlays)) { if ($o.type -eq 'ticker' -and $o.settings.rumble -and $o.settings.rumble.url) { $r = [pscustomobject]@{ url = $o.settings.rumble.url; every = $o.settings.rumble.every; liveChat = $false }; break } }
    }
    if (-not $r) { return $null }
    $ok = ([string]$r.url) -match '^https://'
    if (-not $ok -and $env:AOH_TEST_RUMBLE -eq '1') { $ok = ([string]$r.url) -match '^http://127\.0\.0\.1:' }   # for the author's tests only
    if (-not $ok) { return $null }
    return $r
}
function Add-RumbleChat($id, $user, $userId, $text, $color, $avatar, $badges) {
    $b = New-Object System.Collections.ArrayList
    foreach ($x in @($badges)) { if ($x) { [void]$b.Add([ordered]@{ name = [string]$x }) } }
    $o = [ordered]@{ type = 'chat'; platform = 'rumble'; id = [string]$id; user = [string]$user; userId = [string]$userId; text = [string]$text; color = [string]$color; avatar = [string]$avatar; badges = $b.ToArray() }
    Add-HubEvent (ConvertTo-Json -InputObject $o -Compress -Depth 4)
}
function Test-SeenKey($list, [string]$key) { if ($list -contains $key) { return $true }; [void]$list.Add($key); while ($list.Count -gt 800) { $list.RemoveAt(0) }; return $false }

function Read-Rumble($r) {
    $url = [string]$r.url
    $h = Get-ShortHash $url
    $j = ConvertFrom-Json (Get-WebText $url 5000)
    if ($j.errors) { throw 'Rumble says the link is not valid (make a new one at rumble.com/account/livestream-api)' }
    $found = New-Object System.Collections.ArrayList
    $chat = New-Object System.Collections.ArrayList
    $liveId = ''
    foreach ($ls in @($j.livestreams)) {
        if (-not $ls) { continue }
        if ($ls.is_live -and -not $liveId) { $liveId = [string]$ls.id }
        if (-not $ls.chat) { continue }
        foreach ($x in (@($ls.chat.recent_rants) + @($ls.chat.latest_rant))) {
            if (-not $x -or -not $x.username) { continue }
            $usd = $x.amount_dollars; if ($null -eq $usd -and $null -ne $x.amount_cents) { $usd = [double]$x.amount_cents / 100 }
            [void]$found.Add(@{ key = "rant|$($x.username)|$($x.created_on)|$($x.amount_cents)"; t = (Get-Time $x.created_on)
                e = [pscustomobject]@{ platform = 'rumble'; name = $x.username; amount = (Format-Usd $usd); what = 'Rant'; kind = 'tip'; num = $usd; unit = 'money'; currency = 'USD' } })
        }
        foreach ($m in (@($ls.chat.recent_messages) + @($ls.chat.latest_message))) {
            if (-not $m -or -not $m.username) { continue }
            [void]$chat.Add(@{ key = "chat|$($m.username)|$($m.created_on)|$($m.text)"; t = (Get-Time $m.created_on); m = $m })
        }
    }
    if ($j.subscribers) {
        foreach ($x in (@($j.subscribers.recent_subscribers) + @($j.subscribers.latest_subscriber))) {
            if (-not $x) { continue }
            $n = $x.username; if (-not $n) { $n = $x.user }
            if (-not $n) { continue }
            [void]$found.Add(@{ key = "sub|$n|$($x.subscribed_on)"; t = (Get-Time $x.subscribed_on); e = [pscustomobject]@{ platform = 'rumble'; name = $n; amount = ''; what = 'Subscribed'; kind = 'sub' } })
        }
    }
    if ($j.gifted_subs) {
        foreach ($g in (@($j.gifted_subs.recent_gifted_subs) + @($j.gifted_subs.latest_gifted_sub))) {
            if (-not $g -or -not $g.purchased_by) { continue }
            $c = 1; try { $c = [int]$g.total_gifts } catch {}
            if ($c -lt 1) { $c = 1 }
            $what = 'Gifted Subs'; if ($c -eq 1) { $what = 'Gifted Sub' }
            [void]$found.Add(@{ key = "gift|$($g.purchased_by)|$($g.total_gifts)|$($g.gift_type)|$($g.video_id)"; t = 0
                e = [pscustomobject]@{ platform = 'rumble'; name = $g.purchased_by; amount = [string]$c; what = $what; kind = 'gift'; num = $c; unit = 'count' } })
        }
    }
    if ($j.followers) {
        foreach ($f in (@($j.followers.recent_followers) + @($j.followers.latest_follower))) {
            if (-not $f -or -not $f.username) { continue }
            [void]$found.Add(@{ key = "follow|$($f.username)|$($f.followed_on)"; t = (Get-Time $f.followed_on); e = [pscustomobject]@{ platform = 'rumble'; name = $f.username; amount = ''; what = 'Followed'; kind = 'follow' } })
        }
    }
    # Support: the first read only remembers what's already there, so old support isn't replayed.
    $first = -not $script:RumbleSeen.ContainsKey($h)
    if ($first) { $script:RumbleSeen[$h] = New-Object System.Collections.ArrayList }
    foreach ($f in ($found | Sort-Object { $_.t })) {
        if (Test-SeenKey $script:RumbleSeen[$h] $f.key) { continue }
        if (-not $first) { [void](Add-Support $f.e) }
    }
    # Chat (skipped while the faster live chat feed is connected).
    $ck = "$h-chat"
    $firstChat = -not $script:RumbleSeen.ContainsKey($ck)
    if ($firstChat) { $script:RumbleSeen[$ck] = New-Object System.Collections.ArrayList }
    foreach ($c in ($chat | Sort-Object { $_.t })) {
        if (Test-SeenKey $script:RumbleSeen[$ck] $c.key) { continue }
        if ($firstChat -or $script:Sse.connected) { continue }
        $m = $c.m
        Add-RumbleChat ('api' + (Get-ShortHash $c.key)) $m.username '' $m.text '' '' @($m.badges)
    }
    Save-RumbleSeen
    $script:RumbleLiveId = $liveId
}
function Invoke-RumbleChecks {
    $r = Get-RumbleSettings
    if (-not $r) { $script:RumbleStatus = ''; $script:RumbleLiveId = ''; return }
    $now = Get-NowMs
    if ($now -lt $script:RumbleNext) { return }
    $every = 5; try { $every = [int]$r.every } catch {}
    if ($every -lt 3) { $every = 3 }
    $script:RumbleNext = $now + $every * 1000
    try { Read-Rumble $r; $script:RumbleStatus = 'ok' } catch { $script:RumbleStatus = 'error: ' + $_.Exception.Message }
}

# ---- the faster live chat feed (server-sent events) ----
$script:Sse = @{ want = ''; req = $null; ar = $null; stream = $null; task = $null; buf = $null; dec = $null; text = ''; data = ''; users = @{}; connected = $false; next = [long]0; fails = 0; state = 'off' }
function ConvertFrom-Base36([string]$s) {
    $s = $s.Trim().ToLower(); if ($s.StartsWith('v')) { $s = $s.Substring(1) }
    $digits = '0123456789abcdefghijklmnopqrstuvwxyz'; $v = [long]0
    foreach ($c in $s.ToCharArray()) { $d = $digits.IndexOf($c); if ($d -lt 0) { return [long]0 }; $v = $v * 36 + $d }
    return $v
}
function Stop-Sse([string]$state) {
    try { if ($script:Sse.stream) { $script:Sse.stream.Dispose() } } catch {}
    try { if ($script:Sse.req) { $script:Sse.req.Abort() } } catch {}
    $script:Sse.req = $null; $script:Sse.ar = $null; $script:Sse.stream = $null; $script:Sse.task = $null
    $script:Sse.text = ''; $script:Sse.data = ''; $script:Sse.connected = $false
    if ($state) { $script:Sse.state = $state }
}
function Start-Sse([string]$id36) {
    $b10 = ConvertFrom-Base36 $id36
    if ($b10 -le 0) { $script:Sse.state = 'no stream id'; return }
    try {
        $feed = "https://web7.rumble.com/chat/api/chat/$b10/stream"
        if ($env:AOH_TEST_RUMBLE -eq '1' -and $env:AOH_TEST_FEED) { $feed = $env:AOH_TEST_FEED + $b10 }   # for the author's tests only
        $q = [Net.HttpWebRequest]::Create($feed)
        $q.Accept = 'text/event-stream'
        $q.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AOverlayHub/' + $AppVersion
        $q.ReadWriteTimeout = 120000
        $script:Sse.req = $q
        $script:Sse.ar = $q.BeginGetResponse($null, $null)
        $script:Sse.state = 'connecting'
    } catch { Stop-SseFailed $_.Exception.Message }
}
function Stop-SseFailed([string]$why) {
    Stop-Sse ('reconnecting (' + $why + ')')
    $script:Sse.fails++
    $script:Sse.next = (Get-NowMs) + [Math]::Min(60000, 3000 * [Math]::Pow(2, [Math]::Min(5, $script:Sse.fails)))
}
function Invoke-SseData([string]$d) {
    try { $j = ConvertFrom-Json $d } catch { return }
    foreach ($u in @($j.data.users)) { if ($u -and $u.id) { $script:Sse.users[[string]$u.id] = $u } }
    $t = [string]$j.type
    if ($t -eq 'init') { return }   # what was said before we connected: not replayed
    if ($t -eq 'messages') {
        foreach ($m in @($j.data.messages)) {
            if (-not $m) { continue }
            $u = $script:Sse.users[[string]$m.user_id]
            $name = ''; $color = ''; $avatar = ''; $badges = @()
            if ($u) { $name = [string]$u.username; $color = [string]$u.color; $avatar = [string]$u.'image.1'; $badges = @($u.badges) }
            if (-not $name) { continue }
            Add-RumbleChat $m.id $name $m.user_id $m.text $color $avatar $badges
        }
    } elseif ($t -like 'delete*') {
        $ids = @($j.data.message_ids | ForEach-Object { [string]$_ })
        Add-HubEvent ('{"type":"chat-delete","platform":"rumble","ids":' + (Get-Json (New-Object System.Collections.ArrayList(, $ids))) + '}')
    }
}
function Update-Sse {
    $r = Get-RumbleSettings
    $want = ''
    if ($r -and $r.liveChat -and $script:RumbleLiveId) { $want = $script:RumbleLiveId }
    if ($want -ne $script:Sse.want) { Stop-Sse 'off'; $script:Sse.want = $want; $script:Sse.next = 0; $script:Sse.fails = 0 }
    if (-not $want) { if ($r -and $r.liveChat) { $script:Sse.state = 'waiting for you to go live' }; return }
    if (-not $script:Sse.req -and (Get-NowMs) -ge $script:Sse.next) { Start-Sse $want }
    if ($script:Sse.ar -and $script:Sse.ar.IsCompleted) {
        try {
            $resp = $script:Sse.req.EndGetResponse($script:Sse.ar)
            $script:Sse.ar = $null
            $script:Sse.stream = $resp.GetResponseStream()
            $script:Sse.buf = New-Object byte[] 16384
            $script:Sse.dec = [Text.Encoding]::UTF8.GetDecoder()
            $script:Sse.task = $script:Sse.stream.ReadAsync($script:Sse.buf, 0, $script:Sse.buf.Length)
            $script:Sse.connected = $true; $script:Sse.fails = 0; $script:Sse.state = 'connected'
        } catch { $script:Sse.ar = $null; Stop-SseFailed $_.Exception.Message; return }
    }
    $guard = 0
    while ($script:Sse.task -and $script:Sse.task.IsCompleted -and $guard -lt 50) {
        $guard++
        if ($script:Sse.task.IsFaulted -or $script:Sse.task.IsCanceled) { Stop-SseFailed 'connection lost'; return }
        $n = $script:Sse.task.Result
        if ($n -le 0) { Stop-SseFailed 'closed by Rumble'; return }
        $chars = New-Object char[] ($n + 4)
        $cn = $script:Sse.dec.GetChars($script:Sse.buf, 0, $n, $chars, 0)
        $script:Sse.text += (New-Object string($chars, 0, $cn))
        while (($i = $script:Sse.text.IndexOf("`n")) -ge 0) {
            $line = $script:Sse.text.Substring(0, $i).TrimEnd("`r")
            $script:Sse.text = $script:Sse.text.Substring($i + 1)
            if ($line -eq '') { if ($script:Sse.data) { Invoke-SseData $script:Sse.data }; $script:Sse.data = '' }
            elseif ($line.StartsWith('data:')) { $part = $line.Substring(5).TrimStart(); if ($script:Sse.data) { $script:Sse.data += "`n" + $part } else { $script:Sse.data = $part } }
        }
        try { $script:Sse.task = $script:Sse.stream.ReadAsync($script:Sse.buf, 0, $script:Sse.buf.Length) } catch { Stop-SseFailed 'connection lost'; return }
    }
}

# ------------------------------------------------------------------ fonts
# Every installed font family, including OpenType (.otf) fonts and fonts installed only for this user.
$script:FontsJson = $null
function Add-FamilyNames($set, $f) {
    $src = [string]$f.Source
    if ($src.Contains('#')) { $src = $src.Substring($src.LastIndexOf('#') + 1) }
    if ($src) { [void]$set.Add($src.Trim()) }
    foreach ($v in $f.FamilyNames.Values) { if ($v) { [void]$set.Add(([string]$v).Trim()) } }
}
function Get-FontsJson {
    if ($script:FontsJson) { return $script:FontsJson }
    $names = New-Object 'System.Collections.Generic.SortedSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    try {
        Add-Type -AssemblyName PresentationCore
        foreach ($f in [Windows.Media.Fonts]::SystemFontFamilies) { Add-FamilyNames $names $f }
        $ud = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        if (Test-Path -LiteralPath $ud) { foreach ($f in [Windows.Media.Fonts]::GetFontFamilies($ud + '\')) { Add-FamilyNames $names $f } }
    } catch { Write-Log "Font list (WPF) failed: $($_.Exception.Message)" }
    try {
        Add-Type -AssemblyName System.Drawing
        foreach ($f in (New-Object System.Drawing.Text.InstalledFontCollection).Families) { [void]$names.Add($f.Name) }
    } catch {}
    $list = New-Object System.Collections.ArrayList
    foreach ($n in $names) { if ($n -and $n -notmatch '^Global (User Interface|Sans Serif|Serif|Monospace)$') { [void]$list.Add($n) } }
    $script:FontsJson = Get-Json $list
    return $script:FontsJson
}

# ------------------------------------------------------------------ moderation (used by the Streamer.bot actions)
$script:ModVer = $Base
function New-ModSettings {
    return [ordered]@{ enabled = $true; action = 'timeout'; timeout = 600; reason = 'Spam message'; delete = $true; exemptMods = $true; exemptVip = $true
        trustedAfter = 4; minLength = 12; learn = $true; announce = $true; commands = $true; kick = $true; twitch = $true; youtube = $true }
}
function ConvertTo-Norm([string]$s) {
    if (-not $s) { return '' }
    $sb = New-Object Text.StringBuilder; $space = $false
    foreach ($c in $s.ToLowerInvariant().ToCharArray()) {
        if ([char]::IsLetterOrDigit($c)) { [void]$sb.Append($c); $space = $false }
        elseif (-not $space -and $sb.Length -gt 0) { [void]$sb.Append(' '); $space = $true }
    }
    return $sb.ToString().Trim()
}
function New-Phrase([string]$text, [string]$source, [string]$by, [string]$platform) {
    return [pscustomobject][ordered]@{ id = ('p' + (Get-NowMs) + (Get-Random -Maximum 99999)); text = $text.Trim(); on = $true; source = $source; by = $by; platform = $platform; added = (Get-NowMs) }
}
function Set-ModSettings($from) {
    $d = New-ModSettings
    # start from the current settings, so a change to a few of them keeps the rest
    if ($script:ModSettings) { foreach ($k in @($d.Keys)) { if ($script:ModSettings.Contains($k)) { $d[$k] = $script:ModSettings[$k] } } }
    foreach ($k in @($d.Keys)) {
        $p = $from.PSObject.Properties[$k]
        if ($null -eq $p -or $null -eq $p.Value) { continue }
        try { $d[$k] = [System.Management.Automation.LanguagePrimitives]::ConvertTo($p.Value, $d[$k].GetType()) } catch {}
    }
    if (@('timeout', 'ban') -notcontains $d.action) { $d.action = 'timeout' }
    if ($d.timeout -lt 1) { $d.timeout = 1 }; if ($d.timeout -gt 1209600) { $d.timeout = 1209600 }
    $d.reason = Limit-Text $d.reason 200
    $script:ModSettings = $d
}
function Import-Mod {
    $script:ModSettings = New-ModSettings
    $script:ModPhrases = New-Object System.Collections.ArrayList
    $script:ModLog = New-Object System.Collections.ArrayList
    $t = Read-Text $ModPath
    if ($t) {
        try {
            $j = ConvertFrom-Json $t
            if ($j.settings) { Set-ModSettings $j.settings }
            foreach ($p in @($j.phrases)) { if ($p -and $p.text) { [void]$script:ModPhrases.Add($p) } }
            foreach ($l in @($j.log)) { if ($l) { [void]$script:ModLog.Add($l) } }
            return
        } catch { Write-Log "Could not read moderation.json: $($_.Exception.Message)" }
    }
    $starter = Read-Text (Join-Path $AppDir 'starter-phrases.txt')
    if ($starter) { foreach ($l in ($starter -split "`r?`n")) { if ($l.Trim()) { [void]$script:ModPhrases.Add((New-Phrase $l 'starter' '' '')) } } }
    Save-Mod
}
function Save-Mod {
    $script:ModJson = '{"settings":' + (ConvertTo-Json -InputObject $script:ModSettings -Compress) + ',"phrases":' + (Get-Json $script:ModPhrases 3) + ',"log":' + (Get-Json $script:ModLog 3) + '}'
    try { Write-TextSafe $ModPath $script:ModJson } catch { Write-Log "Could not save moderation.json: $($_.Exception.Message)" }
    $script:ModVer++
}
function Find-Phrase([string]$norm) {
    foreach ($p in $script:ModPhrases) { if ((ConvertTo-Norm $p.text) -eq $norm) { return $p } }
    return $null
}
function Get-Letters([string]$norm) { return ($norm -replace ' ', '').Length }
function Add-ModPhrase([string]$text, [string]$source, [string]$by, [string]$platform, [bool]$checkLength) {
    $norm = ConvertTo-Norm $text
    if (-not $norm) { return 'empty' }
    if ($checkLength -and (Get-Letters $norm) -lt $script:ModSettings.minLength) { return 'short' }
    $have = Find-Phrase $norm
    if ($have) { if (-not $have.on) { $have.on = $true; return 'added' }; return 'exists' }
    [void]$script:ModPhrases.Add((New-Phrase (Limit-Text $text 300) $source $by $platform))
    return 'added'
}
function Get-ModSbText {
    $s = $script:ModSettings
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append("aoh-mod 1`n")
    foreach ($k in $s.Keys) {
        $v = $s[$k]
        if ($v -is [bool]) { $v = [int]$v }
        [void]$sb.Append($k + '=' + ([string]$v -replace "[`r`n]", ' ') + "`n")
    }
    [void]$sb.Append("---`n")
    foreach ($p in $script:ModPhrases) { if ($p.on) { $n = ConvertTo-Norm $p.text; if ($n) { [void]$sb.Append($n + "`n") } } }
    return $sb.ToString()
}
function Invoke-ModCommand($b) {
    $cmd = [string]$b.cmd; $text = [string]$b.text; $by = [string]$b.by; $plat = [string]$b.platform
    if ($cmd -eq '!phrasemode') {
        $r = $text.Trim().ToLower()
        if ($r -eq 'ban' -or $r -eq 'timeout') { $script:ModSettings.action = $r; Save-Mod }
        if ($script:ModSettings.action -eq 'ban') { return 'Spam phrases now get a permanent ban.' }
        return 'Spam phrases now get a ' + [Math]::Round($script:ModSettings.timeout / 60, 1) + ' minute timeout.'
    }
    if ($cmd -eq '!undophrase') {
        $last = $null
        foreach ($p in $script:ModPhrases) { if (@('learned', 'mod') -contains $p.source -and (-not $last -or $p.added -gt $last.added)) { $last = $p } }
        if (-not $last) { return 'There are no added spam phrases to undo.' }
        $script:ModPhrases.Remove($last); Save-Mod
        return 'Removed the last added spam phrase.'
    }
    if ($cmd -eq '!addphrase') {
        $res = Add-ModPhrase $text 'mod' $by $plat $true
        if ($res -eq 'short') { return "That phrase is too short to add ($($script:ModSettings.minLength) letters minimum)." }
        if ($res -eq 'empty') { return 'Type the phrase after !addphrase.' }
        Save-Mod; return 'Spam phrase added.'
    }
    if ($cmd -eq '!delphrase') {
        $norm = ConvertTo-Norm $text
        $gone = @($script:ModPhrases | Where-Object { (ConvertTo-Norm $_.text) -eq $norm })
        foreach ($g in $gone) { $script:ModPhrases.Remove($g) }
        if ($gone.Count) { Save-Mod; return 'Spam phrase removed.' }
        return "That phrase isn't on the list."
    }
    return ''
}
function Invoke-ModOp($b) {
    $op = [string]$b.op
    switch ($op) {
        'add' { $r = Add-ModPhrase ([string]$b.text) 'you' '' '' $false; if ($r -eq 'empty') { return 'Type a phrase first.' }; if ($r -eq 'exists') { return 'That phrase is already on the list.' } }
        'edit' {
            $p = $script:ModPhrases | Where-Object { $_.id -eq [string]$b.id } | Select-Object -First 1
            if (-not $p) { return 'Not found.' }
            $t = Limit-Text $b.text 300; if (-not (ConvertTo-Norm $t)) { return 'A phrase needs at least one letter or number.' }
            $p.text = $t
        }
        'toggle' { $p = $script:ModPhrases | Where-Object { $_.id -eq [string]$b.id } | Select-Object -First 1; if ($p) { $p.on = [bool]$b.on } }
        'delete' { $p = $script:ModPhrases | Where-Object { $_.id -eq [string]$b.id } | Select-Object -First 1; if ($p) { $script:ModPhrases.Remove($p) } }
        'settings' { if ($b.settings) { Set-ModSettings $b.settings } }
        'clearlog' { $script:ModLog.Clear() }
        'starter' {
            $starter = Read-Text (Join-Path $AppDir 'starter-phrases.txt')
            if ($starter) { foreach ($l in ($starter -split "`r?`n")) { if ($l.Trim()) { [void](Add-ModPhrase $l 'starter' '' '' $false) } } }
        }
        'import' { foreach ($t in @($b.phrases)) { if ($t) { [void](Add-ModPhrase ([string]$t) 'learned' 'older list' '' $false) } } }
        default { return 'Unknown change.' }
    }
    Save-Mod
    return ''
}
Import-Mod

# ---- the Streamer.bot import file ----
function New-SbSubAction([string]$code) {
    $fw = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\'
    return [ordered]@{ name = $null; description = $null; references = @(($fw + 'mscorlib.dll'), ($fw + 'System.dll'), ($fw + 'System.Core.dll'))
        byteCode = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($code)); precompile = $false; delayStart = $false
        saveResultToVariable = $false; saveToVariable = $null; id = [Guid]::NewGuid().ToString(); weight = 0.0; type = 99999; parentId = $null; enabled = $true; index = 0 }
}
function New-SbAction([string]$id, [string]$name, [int[]]$triggers, [string]$code) {
    $tr = foreach ($t in $triggers) { [ordered]@{ id = [Guid]::NewGuid().ToString(); type = $t; enabled = $true; exclusions = @() } }
    return [ordered]@{ id = $id; queue = '00000000-0000-0000-0000-000000000000'; enabled = $true; excludeFromHistory = $true; excludeFromPending = $false
        name = $name; group = 'AOverlay Hub'; alwaysRun = $false; randomAction = $false; concurrent = $true
        triggers = @($tr); subActions = @((New-SbSubAction $code)); collapsedGroups = @() }
}
function Get-SbPackage {
    $dir = Join-Path $AppDir 'streamerbot'
    $mod = (Read-Text (Join-Path $dir 'moderation.cs')) -replace '\{\{HUB_PORT\}\}', [string]$script:Port
    $learn = (Read-Text (Join-Path $dir 'learn.cs')) -replace '\{\{HUB_PORT\}\}', [string]$script:Port
    # Trigger numbers: Kick chat 35010 / banned 35019, Twitch chat 133 / banned 137, YouTube message 4003 / banned 4005.
    $pkg = [ordered]@{
        meta = [ordered]@{ name = 'AOverlay Hub Moderation'; author = $AppCredit; version = $AppVersion
            description = 'Spam phrase moderation for Kick, Twitch and YouTube, managed in AOverlay Hub > Moderation.'; autoRunAction = $null; minimumVersion = $null }
        data = [ordered]@{
            actions = @((New-SbAction 'a0e1c5d2-6b7f-4a0e-9c31-5f3d2b8a7e01' 'AOverlay Hub - Spam Phrase Moderation' @(35010, 133, 4003) $mod),
                        (New-SbAction 'a0e1c5d2-6b7f-4a0e-9c31-5f3d2b8a7e02' 'AOverlay Hub - Learn Phrase From Ban' @(35019, 137, 4005) $learn))
            queues = @(); commands = @(); websocketServers = @(); websocketClients = @(); timers = @()
        }
        version = 24; exportedFrom = '1.0.0'; minimumVersion = '1.0.0'
    }
    $json = ConvertTo-Json -InputObject $pkg -Depth 12 -Compress
    $ms = New-Object IO.MemoryStream
    $gz = New-Object IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Compress)
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $gz.Write($bytes, 0, $bytes.Length); $gz.Close()
    $all = [byte[]]((83, 66, 65, 69) + $ms.ToArray())
    return [Convert]::ToBase64String($all)
}

# ------------------------------------------------------------------ web server
$ContentTypes = @{
    '.html' = 'text/html; charset=utf-8'; '.htm' = 'text/html; charset=utf-8'; '.js' = 'application/javascript; charset=utf-8'
    '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8'
    '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.webp' = 'image/webp'; '.svg' = 'image/svg+xml'
    '.apng' = 'image/apng'; '.ico' = 'image/x-icon'; '.mp4' = 'video/mp4'; '.webm' = 'video/webm'; '.mp3' = 'audio/mpeg'; '.ogg' = 'audio/ogg'; '.wav' = 'audio/wav'
    '.woff' = 'font/woff'; '.woff2' = 'font/woff2'; '.ttf' = 'font/ttf'; '.otf' = 'font/otf'
}
$UploadTypes = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.apng')
function Get-ContentType([string]$path) {
    $ext = [IO.Path]::GetExtension($path).ToLower()
    if ($ContentTypes.ContainsKey($ext)) { return $ContentTypes[$ext] }
    return 'application/octet-stream'
}
function Send($ctx, [int]$code, [string]$ctype, [byte[]]$bytes, $headers) {
    $res = $ctx.Response
    try {
        $res.StatusCode = $code
        $res.ContentType = $ctype
        $res.Headers['Cache-Control'] = 'no-store'
        if ($headers) { foreach ($k in $headers.Keys) { $res.Headers[$k] = $headers[$k] } }
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch {} finally { try { $res.Close() } catch {} }
}
function Send-Text($ctx, [int]$code, [string]$ctype, [string]$text, $headers) { Send $ctx $code $ctype ([Text.Encoding]::UTF8.GetBytes($text)) $headers }
function Send-Json($ctx, [string]$json) { Send-Text $ctx 200 'application/json; charset=utf-8' $json }
function Send-File($ctx, [string]$path, $headers) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Send-Text $ctx 404 'text/plain' 'Not found'; return }
    try { Send $ctx 200 (Get-ContentType $path) ([IO.File]::ReadAllBytes($path)) $headers } catch { Send-Text $ctx 500 'text/plain' 'Could not read file' }
}
function Read-Body($req) {
    $sr = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
    return $sr.ReadToEnd()
}
function Read-BodyJson($req) { try { return ConvertFrom-Json (Read-Body $req) } catch { return $null } }
function Get-JsonString([string]$s) { return (ConvertTo-Json -InputObject $s -Compress) }

function Invoke-Request($ctx) {
    $req = $ctx.Request
    $path = $req.Url.AbsolutePath
    $method = $req.HttpMethod

    # Only answer pages on this computer (protects against other websites poking at it).
    $hostHeader = [string]$req.Headers['Host']
    if ($hostHeader -notmatch ('^(localhost|127\.0\.0\.1)(:' + $script:Port + ')?$')) { Send-Text $ctx 403 'text/plain' 'Forbidden'; return }
    if ($method -eq 'POST' -and $req.Headers['X-AOH'] -ne '1') { Send-Text $ctx 403 'text/plain' 'Forbidden'; return }

    switch -Regex ($path) {
        '^/$|^/panel$|^/index\.html$' { Send-File $ctx (Join-Path $WebDir 'panel.html'); return }
        '^/stage/?$' { Send-File $ctx (Join-Path $WebDir 'stage.html'); return }
        '^/favicon\.ico$' { Send-File $ctx (Join-Path $AppDir 'icon.ico'); return }
        '^/icon\.png$' { Send-File $ctx (Join-Path $AppDir 'icon.png'); return }
        '^/license$' { if (Test-Path -LiteralPath $LicensePath) { Send-Text $ctx 200 'text/plain; charset=utf-8' (Read-Text $LicensePath) } else { Send-Text $ctx 404 'text/plain' 'LICENSE.txt is missing.' }; return }
        '^/web/([A-Za-z0-9._-]+)$' { Send-File $ctx (Join-Path $WebDir $Matches[1]); return }
        '^/web/banners/([A-Za-z0-9._-]+)$' { Send-File $ctx (Join-Path (Join-Path $WebDir 'banners') $Matches[1]); return }
        '^/uploads/([A-Za-z0-9._-]+)$' {
            # Pictures people uploaded: shown as pictures only, never run as a page.
            Send-File $ctx (Join-Path $UploadDir $Matches[1]) @{ 'Content-Security-Policy' = "default-src 'none'; style-src 'unsafe-inline'; img-src data:"; 'X-Content-Type-Options' = 'nosniff' }; return
        }

        '^/api/poll$' {
            $q = $req.QueryString
            if ($q['live'] -eq '1') { $script:LiveSeen = Get-NowMs }
            $sb = New-Object Text.StringBuilder
            [void]$sb.Append('{"v":' + $script:ConfigVer + ',"s":' + $script:SupVer + ',"e":' + $script:EvSeq)
            if ([string]$q['v'] -ne [string]$script:ConfigVer) { [void]$sb.Append(',"config":' + $script:ConfigText) }
            if ([string]$q['s'] -ne [string]$script:SupVer) { [void]$sb.Append(',"support":' + $script:SupportJson) }
            if ([string]$q['e'] -ne [string]$script:EvSeq) {
                $after = [long]0; [void][long]::TryParse([string]$q['e'], [ref]$after)
                $evs = @($script:Events | Where-Object { $_.seq -gt $after } | ForEach-Object { $_.json })
                [void]$sb.Append(',"events":[' + ($evs -join ',') + ']')
            }
            [void]$sb.Append('}')
            Send-Json $ctx $sb.ToString(); return
        }
        '^/api/config$' {
            if ($method -eq 'POST') {
                $body = Read-Body $req
                try { $obj = ConvertFrom-Json $body } catch { Send-Text $ctx 400 'text/plain' 'Bad settings'; return }
                if ($null -eq $obj -or ($null -eq $obj.PSObject.Properties['profiles'] -and $null -eq $obj.PSObject.Properties['overlays'])) { Send-Text $ctx 400 'text/plain' 'Bad settings'; return }
                try { Write-TextSafe $ConfigPath $body } catch { Send-Text $ctx 500 'text/plain' 'Could not save'; return }
                $script:ConfigText = $body; $script:Config = $obj; $script:ConfigVer++
                $script:RumbleNext = 0
                Send-Json $ctx ('{"ok":true,"v":' + $script:ConfigVer + '}'); return
            }
            Send-Json $ctx $script:ConfigText; return
        }
        '^/api/support$' {
            if ($method -ne 'POST') { Send-Json $ctx $script:SupportJson; return }
            $e = Read-BodyJson $req
            if (-not $e) { Send-Text $ctx 400 'text/plain' 'Bad entry'; return }
            $ok = Add-Support $e
            Send-Json $ctx ('{"ok":' + ([string]$ok).ToLower() + '}'); return
        }
        '^/api/support/clear$' {
            $b = Read-BodyJson $req
            if (-not $b -or $b.list) { $script:List.Clear() }
            if (-not $b -or $b.totals) { $script:Totals = [ordered]@{ date = (Get-Date -Format 'yyyy-MM-dd'); kicks = 0; bits = 0; subs = 0; money = [ordered]@{} } }
            Save-Support
            Send-Json $ctx '{"ok":true}'; return
        }
        '^/api/stream/start$' {
            # A new stream: "hide until the first support" starts counting again.
            $script:StreamStart = Get-NowMs; Save-Support
            Send-Json $ctx '{"ok":true}'; return
        }
        '^/api/event$' {
            $body = Read-Body $req
            try { [void](ConvertFrom-Json $body) } catch { Send-Text $ctx 400 'text/plain' 'Bad event'; return }
            Add-HubEvent $body
            Send-Json $ctx '{"ok":true}'; return
        }
        '^/api/status$' {
            if ($method -eq 'POST') {
                $body = Read-Body $req
                try { $j = ConvertFrom-Json $body; $script:LiveStatus = $body; if ($j.profile) { $script:LiveProfiles[[string]$j.profile] = Get-NowMs } } catch {}
                $script:LiveSeen = Get-NowMs
                Send-Json $ctx '{"ok":true}'; return
            }
            $now = Get-NowMs
            $ago = -1; if ($script:LiveSeen -gt 0) { $ago = [int](($now - $script:LiveSeen) / 1000) }
            $lp = [ordered]@{}; foreach ($k in $script:LiveProfiles.Keys) { $lp[$k] = [int](($now - $script:LiveProfiles[$k]) / 1000) }
            $info = [ordered]@{ version = $AppVersion; port = $script:Port; dataDir = $DataDir; liveSecondsAgo = $ago; rumble = $script:RumbleStatus; rumbleLive = [bool]$script:RumbleLiveId; rumbleChat = $script:Sse.state }
            $json = (ConvertTo-Json -InputObject $info -Compress).TrimEnd('}') + ',"live":' + $script:LiveStatus + ',"profiles":' + (ConvertTo-Json -InputObject $lp -Compress) + '}'
            Send-Json $ctx $json; return
        }
        '^/api/music$' { Send-Json $ctx (Get-MusicJson ([string]$req.QueryString['id'])); return }
        '^/api/fonts$' { Send-Json $ctx (Get-FontsJson); return }
        '^/api/probe-aoverlay$' {
            $p = 8095; try { $p = [int]$req.QueryString['port'] } catch {}
            $ok = $false; try { $j = ConvertFrom-Json (Get-WebText ("http://localhost:$p/data") 1500); $ok = [bool]$j.ok } catch {}
            Send-Json $ctx ('{"ok":' + ([string]$ok).ToLower() + '}'); return
        }
        '^/api/kick-lookup$' {
            $ch = ([string]$req.QueryString['channel']).Trim().ToLower()
            if ($ch -notmatch '^[a-z0-9_-]{1,40}$') { Send-Json $ctx '{"ok":false}'; return }
            try {
                $j = ConvertFrom-Json (Get-WebText ("https://kick.com/api/v2/channels/$ch") 6000)
                $id = $j.chatroom.id
                if ($id) { Send-Json $ctx ('{"ok":true,"chatroom":' + [long]$id + '}'); return }
            } catch {}
            Send-Json $ctx '{"ok":false}'; return
        }
        '^/api/rumble-test$' {
            $b = Read-BodyJson $req
            $url = [string]$b.url
            if ($url -notmatch '^https://') { Send-Json $ctx '{"ok":false,"error":"That doesn''t look like a link."}'; return }
            try {
                $j = ConvertFrom-Json (Get-WebText $url 6000)
                if ($j.errors) { Send-Json $ctx '{"ok":false,"error":"Rumble said the link is not valid."}'; return }
                $live = @($j.livestreams | Where-Object { $_.is_live }).Count
                Send-Json $ctx ('{"ok":true,"live":' + $live + '}')
            } catch { Send-Json $ctx ('{"ok":false,"error":' + (Get-JsonString ([string]$_.Exception.Message)) + '}') }
            return
        }
        '^/api/upload$' {
            $name = [string]$req.QueryString['name']
            $ext = [IO.Path]::GetExtension($name).ToLower()
            if ($UploadTypes -notcontains $ext) { Send-Json $ctx '{"ok":false,"error":"Pictures only: PNG, JPG, GIF, WebP, APNG or SVG."}'; return }
            if ($req.ContentLength64 -gt 30MB) { Send-Json $ctx '{"ok":false,"error":"That picture is bigger than 30 MB."}'; return }
            $ms = New-Object IO.MemoryStream
            $req.InputStream.CopyTo($ms)
            $bytes = $ms.ToArray()
            if ($bytes.Length -eq 0 -or $bytes.Length -gt 30MB) { Send-Json $ctx '{"ok":false,"error":"Could not read that picture."}'; return }
            [void](New-Item -ItemType Directory -Force -Path $UploadDir)
            $sha = [Security.Cryptography.SHA256]::Create()
            $hash = (($sha.ComputeHash($bytes)[0..7] | ForEach-Object { $_.ToString('x2') }) -join '')
            $file = $hash + $ext
            [IO.File]::WriteAllBytes((Join-Path $UploadDir $file), $bytes)
            Send-Json $ctx ('{"ok":true,"url":"/uploads/' + $file + '"}'); return
        }

        '^/api/mod$' { Send-Json $ctx ('{"v":' + $script:ModVer + ',"data":' + $script:ModJson + '}'); return }
        '^/api/mod/op$' {
            $b = Read-BodyJson $req
            if (-not $b) { Send-Text $ctx 400 'text/plain' 'Bad change'; return }
            $err = Invoke-ModOp $b
            if ($err) { Send-Json $ctx ('{"ok":false,"error":' + (Get-JsonString $err) + '}') } else { Send-Json $ctx ('{"ok":true,"v":' + $script:ModVer + '}') }
            return
        }
        '^/api/mod/sb$' { Send-Text $ctx 200 'text/plain; charset=utf-8' (Get-ModSbText); return }
        '^/api/mod/learn$' {
            $b = Read-BodyJson $req
            $added = $false
            if ($b -and $script:ModSettings.learn) {
                $r = Add-ModPhrase ([string]$b.text) 'learned' ([string]$b.user) ([string]$b.platform) $true
                if ($r -eq 'added') { $added = $true; Save-Mod }
            }
            $ann = $added -and $script:ModSettings.announce
            Send-Json $ctx ('{"ok":true,"added":' + ([string]$added).ToLower() + ',"announce":' + ([string]$ann).ToLower() + '}'); return
        }
        '^/api/mod/log$' {
            $b = Read-BodyJson $req
            if ($b) {
                $script:ModLog.Insert(0, [pscustomobject][ordered]@{ t = (Get-NowMs); platform = (Limit-Text $b.platform 10); user = (Limit-Text $b.user 60); action = (Limit-Text $b.action 10)
                    phrase = (Limit-Text $b.phrase 200); message = (Limit-Text $b.message 300); ok = [bool]$b.ok })
                while ($script:ModLog.Count -gt 200) { $script:ModLog.RemoveAt($script:ModLog.Count - 1) }
                Save-Mod
            }
            Send-Json $ctx '{"ok":true}'; return
        }
        '^/api/mod/cmd$' {
            $b = Read-BodyJson $req
            $reply = ''; if ($b) { $reply = Invoke-ModCommand $b }
            Send-Json $ctx ('{"ok":true,"reply":' + (Get-JsonString $reply) + '}'); return
        }
        '^/api/mod/sbpackage$' {
            $text = Get-SbPackage
            if ($req.QueryString['download'] -eq '1') { Send-Text $ctx 200 'application/octet-stream' $text @{ 'Content-Disposition' = 'attachment; filename="AOverlay Hub Moderation.sb"' } }
            else { Send-Text $ctx 200 'text/plain; charset=utf-8' $text }
            return
        }

        '^/api/quit$' { Send-Json $ctx '{"ok":true}'; $script:Running = $false; return }
        '^/local/([^/]+)/(.+)$' {
            $o = Get-Overlay ([Uri]::UnescapeDataString($Matches[1]))
            $rel = [Uri]::UnescapeDataString($Matches[2])
            if (-not $o -or $o.type -ne 'file' -or -not $o.settings.path) { Send-Text $ctx 404 'text/plain' 'Not found'; return }
            $baseDir = [IO.Path]::GetFullPath((Split-Path -Parent ([string]$o.settings.path)))
            if (-not $baseDir.EndsWith('\')) { $baseDir += '\' }
            $full = ''
            try { $full = [IO.Path]::GetFullPath((Join-Path $baseDir ($rel -replace '/', '\'))) } catch {}
            if (-not $full -or -not $full.StartsWith($baseDir, [StringComparison]::OrdinalIgnoreCase)) { Send-Text $ctx 403 'text/plain' 'Forbidden'; return }
            Send-File $ctx $full; return
        }
        default { Send-Text $ctx 404 'text/plain' 'Not found'; return }
    }
}

# ------------------------------------------------------------------ start listening
function Start-Listener([int]$p) {
    foreach ($prefixes in @(@("http://localhost:$p/", "http://127.0.0.1:$p/"), @("http://localhost:$p/"))) {
        $l = New-Object Net.HttpListener
        foreach ($x in $prefixes) { $l.Prefixes.Add($x) }
        try { $l.Start(); return $l } catch { try { $l.Close() } catch {} }
    }
    return $null
}
$want = $Port
if ($want -le 0) { try { $want = [int]$script:Config.port } catch { $want = 0 } }
if ($want -le 0 -or $want -gt 65535) { $want = 8096 }
$listener = $null
for ($i = 0; $i -lt 10 -and -not $listener; $i++) {
    $listener = Start-Listener ($want + $i)
    if ($listener) { $script:Port = $want + $i }
}
if (-not $listener) {
    Write-Log "Could not start: ports $want to $($want + 9) are all in use."
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show("AOverlay Hub could not start because ports $want to $($want + 9) are in use by other programs.", $AppTitle)
    } catch {}
    exit 1
}
try { Write-TextSafe $PortFile ([string]$script:Port) } catch {}
Write-Log "AOverlay Hub $AppVersion started on port $($script:Port)"
$PanelUrl = "http://localhost:$($script:Port)/"

# ------------------------------------------------------------------ tray icon
$script:Running = $true
$tray = $null
if (-not $NoTray) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $tray = New-Object Windows.Forms.NotifyIcon
        $icoPath = Join-Path $AppDir 'icon.ico'
        if (Test-Path -LiteralPath $icoPath) { $tray.Icon = New-Object Drawing.Icon($icoPath) } else { $tray.Icon = [Drawing.SystemIcons]::Application }
        $tray.Text = "$AppTitle (port $($script:Port)) - by $AppCredit"
        $menu = New-Object Windows.Forms.ContextMenuStrip
        $miOpen = $menu.Items.Add('Open control panel')
        $miOpen.Add_Click({ Start-Process $PanelUrl })
        $miFolder = $menu.Items.Add('Open settings folder')
        $miFolder.Add_Click({ Start-Process explorer.exe $DataDir })
        [void]$menu.Items.Add('-')
        $miCredit = $menu.Items.Add("$AppTitle $AppVersion - made and distributed by $AppCredit  $AppContact")
        $miCredit.Enabled = $false
        $miLicense = $menu.Items.Add('Read the license')
        $miLicense.Add_Click({ if (Test-Path -LiteralPath $LicensePath) { Start-Process notepad.exe "`"$LicensePath`"" } })
        [void]$menu.Items.Add('-')
        $miQuit = $menu.Items.Add('Quit AOverlay Hub')
        $miQuit.Add_Click({ $script:Running = $false })
        $tray.ContextMenuStrip = $menu
        $tray.Add_DoubleClick({ Start-Process $PanelUrl })
        $tray.Visible = $true
    } catch { Write-Log "Tray icon not available: $($_.Exception.Message)"; $tray = $null }
}

if (-not $Background) { Start-Process $PanelUrl }

# ------------------------------------------------------------------ main loop
$ar = $listener.BeginGetContext($null, $null)
$lastTimers = [long]0
while ($script:Running) {
    try {
        if ($ar.AsyncWaitHandle.WaitOne(100)) {
            $ctx = $null
            try { $ctx = $listener.EndGetContext($ar) } catch {}
            $ar = $listener.BeginGetContext($null, $null)
            if ($ctx) { try { Invoke-Request $ctx } catch { Write-Log "Request failed: $($_.Exception.Message)"; try { $ctx.Response.Close() } catch {} } }
        }
        $now = Get-NowMs
        if ($now - $lastTimers -ge 1000) { $lastTimers = $now; try { Invoke-RumbleChecks } catch {} }
        try { Update-Sse } catch { Write-Log "Rumble live chat: $($_.Exception.Message)" }
        if ($tray) { [Windows.Forms.Application]::DoEvents() }
    } catch { Write-Log "Loop error: $($_.Exception.Message)"; Start-Sleep -Milliseconds 200 }
}

Write-Log 'AOverlay Hub stopped'
try { $listener.Stop(); $listener.Close() } catch {}
if ($tray) { $tray.Visible = $false; $tray.Dispose() }
try { $mutex.ReleaseMutex() } catch {}
