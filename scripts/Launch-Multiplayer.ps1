[CmdletBinding(DefaultParameterSetName='Launch')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='Launch')][ValidateSet('Coop','Versus')][string]$Mode,
    [Parameter(Mandatory=$true,ParameterSetName='Launch')][ValidateSet('Host','Join')][string]$Role,
    [Parameter(Mandatory=$true,ParameterSetName='Collect')][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,119}$')][string]$CollectSession,
    [string]$WorkRoot,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,79}(\.unr)?$')][string]$Map,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$')][string]$Server = '127.0.0.1',
    [ValidateRange(1024,65532)][int]$Port = 7777,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,23}$')][string]$PlayerName = 'Harry',
    [ValidateSet('Harry','Ron','Hermione')][string]$Character = 'Harry',
    [ValidateRange(2,8)][int]$MaxPlayers = 2,
    [ValidateRange(1,99)][int]$ScoreLimit = 3,
    [ValidateSet('None','RictusempraLessonComplete')][string]$TestStage = 'None',
    [ValidateSet('None','Health','Lumos','Pickup','PickupNet','AIInspect','AICombat','AICombatDeath','AISnail','Travel','MountRootB0','MountRootB1')][string]$RuntimeProbe = 'None',
    [switch]$CapturedAuthorityDiagnostic,
    [switch]$FirstIntroPreflight,
    [ValidateSet('None','MissingAck0','MissingAck1','DuplicateCallbacks','DeathWalk0','DeathWalk1')][string]$IntroFault = 'None',
    [switch]$PrepareOnly,
    [switch]$Unattended
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if ($Mode -eq 'Coop' -and $MaxPlayers -ne 2) { throw 'Co-op remains limited to two players.' }

function Get-EngineLogCandidates {
    param([string]$Root, [string]$LogName, [string]$RequestedFolder, [string]$RuntimeIni)
    $candidates = @((Join-Path $Root "System\$LogName"))
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $defaultConfig = Join-Path $Root 'System\Default.ini'
    if ($documents -and (Test-Path -LiteralPath $defaultConfig)) {
        $defaults = Get-Content -LiteralPath $defaultConfig -Raw
        $folderMatch = [regex]::Match($defaults, '(?im)^\s*UserFolder\s*=\s*([^\r\n]+)')
        if ($folderMatch.Success) {
            $candidates += Join-Path (Join-Path $documents $folderMatch.Groups[1].Value.Trim()) $LogName
        }
        if ($RequestedFolder) { $candidates += Join-Path (Join-Path $documents $RequestedFolder) $LogName }
    }
    # Old manifests predate native log discovery. The runtime INI may already
    # contain the absolute SavePath selected during M212 bootstrap.
    if ($RuntimeIni -and (Test-Path -LiteralPath $RuntimeIni)) {
        $runtimeText = Get-Content -LiteralPath $RuntimeIni -Raw
        $saveMatch = [regex]::Match($runtimeText, '(?im)^\s*SavePath\s*=\s*([^\r\n]+)')
        if ($saveMatch.Success -and [IO.Path]::IsPathRooted($saveMatch.Groups[1].Value.Trim())) {
            $savePath = $saveMatch.Groups[1].Value.Trim().TrimEnd('\','/')
            if ((Split-Path $savePath -Leaf) -match '(?i)^Slot[0-9]+$') { $savePath = Split-Path $savePath -Parent }
            if ((Split-Path $savePath -Leaf) -ieq 'Save') { $candidates += Join-Path (Split-Path $savePath -Parent) $LogName }
        }
    }
    return @($candidates | Select-Object -Unique)
}

if ($PSCmdlet.ParameterSetName -eq 'Collect') {
    $collectionRoot = Join-Path $repo ".local\runs\$CollectSession"
    $collectionManifest = Join-Path $collectionRoot 'launch.json'
    if (!(Test-Path -LiteralPath $collectionManifest -PathType Leaf)) { throw "Session not found: $CollectSession" }
    $record = Get-Content -LiteralPath $collectionManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $logName = "HP2MP-$CollectSession.log"
    $candidates = @($record.engineLogCandidates) + @(Get-EngineLogCandidates $record.workRoot $logName $record.userFolder $record.engineIni)
    $copied = @()
    $savePaths = @()
    foreach ($candidate in @($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        if (!(Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $destination = Join-Path $collectionRoot ('engine-{0}.log' -f $copied.Count)
        Copy-Item -LiteralPath $candidate -Destination $destination -Force
        $item = Get-Item -LiteralPath $candidate
        $copied += [PSCustomObject]@{source=$candidate; snapshot=$destination; bytes=$item.Length; modified=$item.LastWriteTimeUtc}
        foreach ($line in (Get-Content -LiteralPath $destination)) {
            if ($line -match 'Save Slot Path:\s*(.+)$') { $savePaths += $Matches[1] }
        }
    }
    $record | Add-Member -NotePropertyName collectedLogs -NotePropertyValue @($copied) -Force
    $record | Add-Member -NotePropertyName observedSaveSlotPaths -NotePropertyValue @($savePaths | Select-Object -Unique) -Force
    $record | Add-Member -NotePropertyName lastCollected -NotePropertyValue (Get-Date -Format o) -Force
    if ($copied.Count) {
        $latest = $copied | Sort-Object modified -Descending | Select-Object -First 1
        $record | Add-Member -NotePropertyName engineLog -NotePropertyValue $latest.source -Force
        $record | Add-Member -NotePropertyName engineLogLocationVerified -NotePropertyValue $true -Force
    } else {
        $record | Add-Member -NotePropertyName engineLogLocationVerified -NotePropertyValue $false -Force
        Write-Warning 'No engine log found yet. Process creation does not prove engine initialization.'
    }
    $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $collectionManifest -Encoding UTF8
    $record
    return
}

if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\game' }
if (!(Test-Path -LiteralPath $WorkRoot -PathType Container)) { throw 'Development game missing. Run Build.ps1 first.' }
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path
if (!(Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-development-copy.json'))) {
    throw 'WorkRoot must be a prepared development copy; the original installation is not a launch target.'
}
$system = Join-Path $WorkRoot 'System'
$executable = Join-Path $system $(if ($Role -eq 'Host') { 'UCC.exe' } else { 'Game.exe' })
foreach ($required in @($executable, (Join-Path $system 'Default.ini'), (Join-Path $system 'DefUser.ini'))) {
    if (!(Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file missing: $required" }
}
if (!$Map) { $Map = if ($Mode -eq 'Coop') { 'Ch1Rictusempra' } else { 'HPV_Entry' } }
$mapName = $Map -replace '(?i)\.unr$', ''
if ($TestStage -ne 'None' -and ($Mode -ne 'Coop' -or $Role -ne 'Host' -or $mapName -ine 'Ch1Rictusempra')) {
    throw 'RictusempraLessonComplete is an explicit test fixture for Coop Host on Ch1Rictusempra only.'
}
if ($RuntimeProbe -ne 'None' -and ($Mode -ne 'Coop' -or $Role -ne 'Host' -or $TestStage -ne 'RictusempraLessonComplete')) {
    throw 'RuntimeProbe is an explicit disposable Coop Host Ch1 fixture; ordinary play keeps it off.'
}
if ($CapturedAuthorityDiagnostic -and ($Mode -ne 'Coop' -or $Role -ne 'Host' -or $mapName -ine 'Ch1Rictusempra' -or $TestStage -ne 'RictusempraLessonComplete' -or $RuntimeProbe -notin @('None','AIInspect','AICombat','AICombatDeath','AISnail','Travel','MountRootB0','MountRootB1'))) {
    throw 'CapturedAuthorityDiagnostic requires Coop Host Ch1 lesson-complete stage without another active probe.'
}
if ($FirstIntroPreflight -and !$CapturedAuthorityDiagnostic) {
    throw 'FirstIntroPreflight requires the explicit CapturedAuthorityDiagnostic fixture.'
}
if ($IntroFault -ne 'None' -and !$FirstIntroPreflight) {
    throw 'IntroFault requires explicit FirstIntroPreflight.'
}
if ($RuntimeProbe -in @('MountRootB0','MountRootB1','Travel') -and (!$FirstIntroPreflight -or $IntroFault -ne 'None')) {
    throw 'MountRootB0/B1/Travel requires normal FirstIntroPreflight without an injected fault.'
}
if ($Role -eq 'Host' -and !(Test-Path -LiteralPath (Join-Path $WorkRoot "Maps\$mapName.unr") -PathType Leaf)) {
    throw "Map is not installed: $mapName.unr"
}
# Only an address/hostname is accepted, never an Unreal URL or extra URL options.
if ([Uri]::CheckHostName($Server) -notin @([UriHostNameType]::Dns,[UriHostNameType]::IPv4)) {
    throw 'Server must be an IPv4 address or DNS hostname without a port, slash or URL options.'
}
$gameClass = if ($Mode -eq 'Coop') { 'HGame.HPCoopGame' } else { 'HGame.HPVersusGame' }
$pawnClass = if ($Mode -eq 'Coop') { 'HGame.HPCoopHarry' } else { 'HGame.HPVersusHarry' }
$localGameClass = if ($Role -eq 'Join') { 'Engine.GameInfo' } else { $gameClass }
$localPawnClass = if ($Role -eq 'Join') { 'HGame.harry' } else { $pawnClass }
$localMap = if ($Role -eq 'Join') { 'Entry.unr' } else { "$mapName.unr" }
$defaultUrlPort = if ($Role -eq 'Join') { 7777 } else { $Port }
if ($Role -eq 'Join' -and !(Test-Path -LiteralPath (Join-Path $WorkRoot 'Maps\Entry.unr') -PathType Leaf)) {
    throw 'The client staging map Entry.unr is missing.'
}

# Refuse to launch into a rebuild. PrepareOnly does not read or execute packages.
if (!$PrepareOnly) {
    # WMI/CIM process queries may be denied even when ordinary process APIs work.
    # A running UCC is accepted only when it is a known server from this launcher;
    # otherwise conservatively assume it may be rebuilding the package.
    $knownHosts = @()
    $runsDirectory = Join-Path $repo '.local\runs'
    if (Test-Path -LiteralPath $runsDirectory) {
        foreach ($runDirectory in (Get-ChildItem -LiteralPath $runsDirectory -Directory)) {
            $savedManifest = Join-Path $runDirectory.FullName 'launch.json'
            if (Test-Path -LiteralPath $savedManifest) {
                try {
                    $saved = Get-Content -LiteralPath $savedManifest -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($saved.status -eq 'STARTED' -and $saved.role -eq 'Host' -and
                        [string]::Equals($saved.workRoot, $WorkRoot, [StringComparison]::OrdinalIgnoreCase)) {
                        $knownHosts += $saved
                    }
                } catch { Write-Verbose "Ignoring unreadable launch manifest: $savedManifest" }
            }
        }
    }
    foreach ($uccProcess in @(Get-Process -Name UCC -ErrorAction SilentlyContinue)) {
        $uccPath = $null
        try { $uccPath = $uccProcess.Path } catch { Write-Verbose 'UCC executable path unavailable.' }
        if ($uccPath -and ![string]::Equals($uccPath, (Join-Path $system 'UCC.exe'), [StringComparison]::OrdinalIgnoreCase)) { continue }
        $knownServer = $false
        foreach ($known in $knownHosts) {
            if ($known.processId -ne $uccProcess.Id) { continue }
            try {
                # Check creation time too: an old manifest's PID can be reused.
                if ([Math]::Abs(($uccProcess.StartTime.ToUniversalTime() - ([DateTime]$known.started).ToUniversalTime()).TotalSeconds) -le 10) {
                    $knownServer = $true
                }
            } catch { Write-Verbose 'UCC creation time unavailable; treating process as unrecognized.' }
        }
        if (!$knownServer) { throw "Unrecognized UCC process $($uccProcess.Id) may be building this copy. Wait for it to finish." }
    }
    $modeBuild = Join-Path $repo $(if ($Mode -eq 'Versus' -and (Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-versus-v16-source.json'))) {
        '.local\last-build-v16.json'
    } else { '.local\last-build-coop.json' })
    $buildFile = if (Test-Path -LiteralPath $modeBuild) { $modeBuild } else { Join-Path $repo '.local\last-build.json' }
    if (!(Test-Path -LiteralPath $buildFile)) { throw 'No recorded clean build. Run Build.ps1 first.' }
    $build = Get-Content -LiteralPath $buildFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$build.passed -or ![string]::Equals($build.workRoot, $WorkRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The latest recorded build is not a PASS for this WorkRoot. Run Build.ps1 first.'
    }
    if ($Mode -eq 'Coop' -and $build.baseline) { throw 'Co-op requires the overlay build. Run Build.ps1 without -Baseline.' }
    $package = Join-Path $system 'HGame.u'
    if (!(Test-Path -LiteralPath $package) -or (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash -ne $build.hgameSha256) {
        throw 'HGame.u does not match the recorded clean build. Rebuild before launching.'
    }
    if ($null -ne $build.PSObject.Properties['m212ShareSha256']) {
        $sharePackage = Join-Path $system 'M212Share.u'
        if ($build.m212ShareSha256 -notmatch '^[A-Fa-f0-9]{64}$' -or
            !(Test-Path -LiteralPath $sharePackage -PathType Leaf) -or
            (Get-FileHash -LiteralPath $sharePackage -Algorithm SHA256).Hash -ne $build.m212ShareSha256) {
            throw 'M212Share.u does not match the recorded clean build. Rebuild or import the complete test build before launching.'
        }
    }
}

function Set-IniValues {
    param([string]$Text, [string]$Section, [System.Collections.IDictionary]$Values)
    $lines = [Collections.Generic.List[string]]::new()
    $inside = $false
    $found = $false
    $emitted = $false
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*\[([^]]+)\]\s*$') {
            if ($inside -and !$emitted) {
                foreach ($key in $Values.Keys) { $lines.Add("$key=$($Values[$key])") }
                $emitted = $true
            }
            $inside = $Matches[1] -ieq $Section
            if ($inside) { $found = $true }
        }
        if ($inside -and $line -match '^\s*([^;=]+?)\s*=' -and $Values.Contains($Matches[1].Trim())) { continue }
        $lines.Add($line)
    }
    if (!$found) { $lines.Add("[$Section]") }
    if (!$emitted) { foreach ($key in $Values.Keys) { $lines.Add("$key=$($Values[$key])") } }
    return ($lines -join "`r`n")
}

$session = '{0}-{1}-{2}-{3}' -f $Mode.ToLowerInvariant(),$Role.ToLowerInvariant(),(Get-Date -Format 'yyyyMMdd-HHmmss-fff'),([Guid]::NewGuid().ToString('N').Substring(0,6))
$stem = "HP2MP-$session"
$runRoot = Join-Path $repo ".local\runs\$session"
$profileRoot = Join-Path $WorkRoot "MPProfiles\$session"
foreach ($directory in @($runRoot, (Join-Path $profileRoot 'Save'), (Join-Path $profileRoot 'Cache'))) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$engineIniName = "$stem.ini"
$userIniName = "$stem-user.ini"
$engineLogName = "$stem.log"
$engineIni = Join-Path $system $engineIniName
$userIni = Join-Path $system $userIniName
$engineLog = Join-Path $system $engineLogName

$config = Get-Content -LiteralPath (Join-Path $system 'Default.ini') -Raw
# Retain required ServerPackages and LAN query support; never advertise to public masters.
$config = (($config -split '\r?\n') | Where-Object {
    $_ -notmatch '(?i)^\s*ServerActors\s*=.*(?:UdpServerUplink|UWeb\.WebServer)' -and
    $_ -notmatch '(?i)^\s*Suppress\s*=\s*ScriptWarning\s*$'
}) -join "`r`n"
$config = $config -replace '(?im)^\s*Paths\s*=\.\.[/\\]save[/\\]\*\.usa\s*$', "Paths=../MPProfiles/$session/Save/*.usa"
$config = Set-IniValues $config 'Core.System' ([ordered]@{
    SavePath="../MPProfiles/$session/Save"; CachePath="../MPProfiles/$session/Cache"; UserFolder="HP2-MP-$session"
})
$config = Set-IniValues $config 'URL' ([ordered]@{
    Protocol='unreal'; Port=$defaultUrlPort; Name=$PlayerName; Class=$localPawnClass;
    Map=$localMap; LocalMap=$localMap; Host=''; Portal=''
})
$config = Set-IniValues $config 'FirstRun' ([ordered]@{FirstRun=469; Reconfig=0; ForceSoftware=0})
$config = Set-IniValues $config 'Engine.Engine' ([ordered]@{DefaultGame=$localGameClass; DefaultServerGame=$localGameClass})
$config = Set-IniValues $config 'Engine.GameInfo' ([ordered]@{MaxPlayers=$MaxPlayers})
# The inherited 2600-byte modem rate starves multiplayer camera and pawn updates.
$config = Set-IniValues $config 'Engine.Player' ([ordered]@{ConfiguredInternetSpeed=50000; ConfiguredLanSpeed=50000})
$config = Set-IniValues $config 'IpDrv.TcpNetDriver' ([ordered]@{MaxClientRate=50000})
$config = Set-IniValues $config $gameClass ([ordered]@{MaxPlayers=$MaxPlayers})
if ($Mode -eq 'Versus') { $config = Set-IniValues $config $gameClass ([ordered]@{ScoreLimit=$ScoreLimit}) }
$config = Set-IniValues $config 'IpDrv.UdpBeacon' ([ordered]@{DoBeacon='False'})
$config = Set-IniValues $config 'IpServer.UdpServerUplink' ([ordered]@{DoUplink='False'})
$config = Set-IniValues $config 'UWeb.WebServer' ([ordered]@{bEnabled='False'})
$config = Set-IniValues $config 'WinDrv.WindowsClient' ([ordered]@{StartupFullscreen='False'; WindowedViewportX=800; WindowedViewportY=600})

$userConfig = Get-Content -LiteralPath (Join-Path $system 'DefUser.ini') -Raw
$userConfig = Set-IniValues $userConfig 'DefaultPlayer' ([ordered]@{Name=$PlayerName; Class=$localPawnClass})
if ($Mode -eq 'Coop') {
    # Remove inherited Versus tokens from all bindings, including arrows/gamepad.
    $userConfig = (($userConfig -split '\r?\n') | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*\bbVersus\w*.*)$') {
            $bindingKey = $Matches[1]
            $bindingValue = (($Matches[2] -split '\s*\|\s*') | Where-Object { $_ -notmatch '\bbVersus\w*\b' }) -join ' | '
            "$bindingKey=$bindingValue"
        } else { $_ }
    }) -join "`r`n"
    $bindings = [ordered]@{
        W='Axis aForward Speed=+300.0'; S='Axis aForward Speed=-300.0';
        A='Axis aStrafe Speed=-300.0'; D='Axis aStrafe Speed=+300.0';
        Space='Jump | Axis aUp Speed=+300.0 | Button bSpellBallAction';
        LeftMouse='AltFire | Button bBroomAction | Button bVendorReply';
        RightMouse='Jump | Button bBroomAction | Button bDuelCycleSpell'; Shift='Button bRun'
    }
} elseif (Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-versus-v16-source.json')) {
    # The supplied v16 DefUser.ini combines the direct buttons with native
    # MoveForward/StrafeLeft/etc. Keep them and add only the score-table key.
    $bindings = [ordered]@{ F3='VersusScores' }
} else {
    # v18's proven direct bridge consumes these buttons. Do not add a second axis.
    $bindings = [ordered]@{
        W='Button bVersusMoveForward'; S='Button bVersusMoveBack';
        A='Button bVersusMoveLeft'; D='Button bVersusMoveRight';
        Up='Button bVersusMoveForward'; Down='Button bVersusMoveBack';
        Left='Button bVersusMoveLeft'; Right='Button bVersusMoveRight';
        Space='Button bVersusJump'; RightMouse='Button bVersusJump';
        LeftMouse='AltFire'; Shift='Button bRun';
        '1'='VersusSpell1'; '2'='VersusSpell2'; '3'='VersusSpell3';
        '4'='VersusSpell4'; '5'='VersusSpell5'; '6'='VersusSpell6'
    }
}
if ($null -ne $bindings) { $userConfig = Set-IniValues $userConfig 'Engine.Input' $bindings }
Set-Content -LiteralPath $engineIni -Value $config -Encoding ASCII
Set-Content -LiteralPath $userIni -Value $userConfig -Encoding ASCII
Copy-Item -LiteralPath $engineIni -Destination (Join-Path $runRoot 'Engine.ini')
Copy-Item -LiteralPath $userIni -Destination (Join-Path $runRoot 'User.ini')

if ($Role -eq 'Host') {
    $url = '{0}.unr?game={1}?MaxPlayers={2}' -f $mapName,$gameClass,$MaxPlayers
    if ($Mode -eq 'Versus') { $url += "?ScoreLimit=$ScoreLimit" }
    if ($TestStage -ne 'None') { $url += "?CoopTestStage=$TestStage" }
    if ($RuntimeProbe -ne 'None') { $url += "?CoopProbe=$RuntimeProbe" }
    if ($CapturedAuthorityDiagnostic) { $url += '?CoopCapturedAuthority=1' }
    if ($FirstIntroPreflight) { $url += '?CoopFirstIntroPreflight=1' }
    if ($IntroFault -ne 'None') { $url += "?CoopIntroFault=$IntroFault" }
    $launchArgs = @('server', $url, "port=$Port")
} else {
    # The temporary standalone map must not run the multiplayer GameInfo or
    # force a network pawn before a connection exists. Both server modes force
    # the correct pawn in Login, so the join URL needs no Class/game override.
    $url = 'unreal://{0}:{1}/?Name={2}' -f $Server,$Port,$PlayerName
    if ($Mode -eq 'Versus') { $url += "?MPCharacter=$Character" }
    # M212 Game.exe's NewWindow command-line branch skips forwarding this
    # connection to an existing client window, allowing local two-client tests.
    $launchArgs = @($url, '-windowed', '-NOFRONTEND', '-NewWindow')
}
# Simple relative ASCII filenames avoid the legacy parser's quoted Unicode INI bug.
$launchArgs += @("INI=$engineIniName", "USERINI=$userIniName", "-log=$engineLogName")
if ($Unattended) {
    # Core.dll parses FORCEFLUSH into GForceLogFlush, preserving diagnostic
    # log output when a test client exits before ordinary buffered flushing.
    $launchArgs += @('-unattended', '-FORCEFLUSH')
}
$logCandidates = @(Get-EngineLogCandidates $WorkRoot $engineLogName "HP2-MP-$session" $engineIni)
$manifest = [ordered]@{
    status='PREPARED'; session=$session; mode=$Mode; role=$Role; created=(Get-Date -Format o);
    workRoot=$WorkRoot; executable=$executable; arguments=$launchArgs; map=$mapName; server=$Server; port=$Port;
    connectUrl=$(if ($Role -eq 'Join') { $url } else { $null });
    localMap=$localMap; localGameClass=$localGameClass; localPawnClass=$localPawnClass; defaultUrlPort=$defaultUrlPort;
    playerName=$PlayerName; character=$Character; testStage=$TestStage; runtimeProbe=$RuntimeProbe; capturedAuthorityDiagnostic=[bool]$CapturedAuthorityDiagnostic; firstIntroPreflight=[bool]$FirstIntroPreflight; introFault=$IntroFault; engineIni=$engineIni; userIni=$userIni; engineLog=$engineLog;
    maxPlayers=$MaxPlayers; scoreLimit=$ScoreLimit;
    engineLogCandidates=$logCandidates; engineLogLocationVerified=$false;
    runRoot=$runRoot; profileRoot=$profileRoot; userFolder="HP2-MP-$session"; processId=$null;
    profileIsolation='UNVERIFIED: M212 bootstrap may select UserFolder/SavePath from Default.ini before the custom INI.';
    note='Preparation or process creation is not a gameplay PASS.'
}
if (!$PrepareOnly) {
    $manifest.hgameSha256 = $build.hgameSha256
    if ($null -ne $build.PSObject.Properties['m212ShareSha256']) {
        $manifest.m212ShareSha256 = $build.m212ShareSha256
    }
}
$manifestPath = Join-Path $runRoot 'launch.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
if (!$PrepareOnly) {
    $previousCompat = $env:__COMPAT_LAYER
    try {
        $env:__COMPAT_LAYER = 'RunAsInvoker'
        $start = @{
            FilePath=$executable; ArgumentList=$launchArgs; WorkingDirectory=$system; PassThru=$true;
            WindowStyle=$(if ($Role -eq 'Host' -or $Unattended) { 'Hidden' } else { 'Normal' })
        }
        # Redirection also selects CreateProcess instead of ShellExecute so the
        # scoped compatibility environment is inherited by the legacy client.
        $logPrefix = if ($Role -eq 'Host') { 'server' } else { 'client' }
        $start.RedirectStandardOutput = Join-Path $runRoot "$logPrefix-stdout.log"
        $start.RedirectStandardError = Join-Path $runRoot "$logPrefix-stderr.log"
        $process = Start-Process @start
        $manifest.status = 'STARTED'
        $manifest.processId = $process.Id
        $manifest.started = Get-Date -Format o
    } catch {
        $manifest.status = 'LAUNCH_FAILED'
        $manifest.error = $_.Exception.Message
        throw
    } finally {
        $env:__COMPAT_LAYER = $previousCompat
        $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    }
}
[PSCustomObject]$manifest
