[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$LogRoot,
    [string[]]$CandidatePaths
)
$ErrorActionPreference = 'Stop'

# Python 3.9 introduced Path.is_relative_to(), which the byte-preserving
# patcher uses while validating every recipe target.
$minimum = [version]'3.9'
if ($PSBoundParameters.ContainsKey('CandidatePaths')) {
    # Explicit candidates also let a regression test model a Store-only PC.
    $candidates = @($CandidatePaths | ForEach-Object {
        [PSCustomObject]@{ Source=$_; Name=[IO.Path]::GetFileName($_) }
    })
} else {
    $candidates = @(Get-Command py, python, python3 -All -CommandType Application -ErrorAction SilentlyContinue)
}
$attempts = @()
$number = 0
foreach ($candidate in $candidates) {
    $number++
    $path = $candidate.Source
    if (!$path -or $path -match '(?i)[\\/]WindowsApps[\\/]') {
        $attempts += "$($candidate.Name): Windows Store alias, skipped"
        continue
    }
    $prefix = if ($candidate.Name -ieq 'py.exe') { @('-3') } else { @() }
    $stdout = Join-Path $LogRoot "python-probe-$number-out.log"
    $stderr = Join-Path $LogRoot "python-probe-$number-err.log"
    try {
        $probe = Start-Process -FilePath $path -ArgumentList @($prefix + '--version') `
            -WorkingDirectory $LogRoot -RedirectStandardOutput $stdout `
            -RedirectStandardError $stderr -WindowStyle Hidden -PassThru -Wait
        $versionText = (Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) +
            (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
        if ($probe.ExitCode -ne 0 -or $versionText -notmatch '(?i)Python\s+(\d+)\.(\d+)(?:\.\d+)?') {
            $attempts += "$path : did not run Python 3 (exit $($probe.ExitCode))"
            continue
        }
        $version = [version]"$($Matches[1]).$($Matches[2])"
        if ($version -lt $minimum) {
            $attempts += "$path : Python $version is older than $minimum"
            continue
        }
        return [PSCustomObject]@{ Path=$path; Prefix=$prefix; Version=$versionText.Trim() }
    } catch {
        $attempts += "$path : $($_.Exception.Message)"
    }
}
throw "Python 3.9 or newer is required to apply HP2 patches. Install Python from python.org, enable 'Add python.exe to PATH', and reopen PowerShell. WindowsApps Store aliases do not count. Checked: $($attempts -join '; ')"
