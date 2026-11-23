<#
.SYNOPSIS
The steps the Makefile runs. Each one is called as `wsl.ps1 <step>` with the Makefile's
settings passed as parameters.

.DESCRIPTION
With -WhatIf, each command that would change something is printed instead of run.
Read-only queries, such as listing distros or finding the newest stage3, still run.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('download', 'image', 'create', 'start', 'provision', 'check-config',
        'ssh', 'status', 'versions', 'halt', 'destroy', 'purge')]
    [string]$Step,
    [string]$Name = 'gentoo-dev',
    [string]$Mirror = 'https://distfiles.gentoo.org/releases/amd64/autobuilds',
    [string]$Flavor = 'stage3-amd64-systemd',
    [string]$Download = 'images/stage3-amd64-systemd.tar.xz',
    [string]$Image = 'images/gentoo-wsl.tar',
    [string]$VmDir = '.vm',
    [int]$HttpPort = 8080,
    [string]$CheckConfigUrl = 'https://raw.githubusercontent.com/moby/moby/master/contrib/check-config.sh'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot
$Cmdlet = $PSCmdlet

# How long `make start` waits for systemd to finish booting.
$BootTimeout = 300

# Without this, wsl.exe writes its own messages and listings in UTF-16.
$env:WSL_UTF8 = '1'

# Windows' bsdtar, not a GNU tar that msys or Git may put first on PATH.
$Tar = Join-Path $env:WINDIR 'System32\tar.exe'

function Invoke-Native {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$File $($Arguments -join ' ') exited with status $LASTEXITCODE"
    }
}

# For commands that change something: prints them instead under -WhatIf.
function Test-Run {
    param([string]$Description)
    $Cmdlet.ShouldProcess($Description, $Description, 'Run')
}

function Invoke-Change {
    param([string]$File, [string[]]$Arguments)
    if (Test-Run "$File $($Arguments -join ' ')") { Invoke-Native $File $Arguments }
}

function Invoke-Guest {
    param([string[]]$Arguments, [switch]$Root)
    $prefix = @('-d', $Name)
    if ($Root) { $prefix += @('-u', 'root') }
    Invoke-Change wsl.exe ($prefix + $Arguments)
}

function Get-Distros {
    param([switch]$Running)
    $list = @('--list', '--quiet')
    if ($Running) { $list += '--running' }
    # With nothing running, wsl.exe prints a message and exits non-zero.
    $ErrorActionPreference = 'Continue'
    @(& wsl.exe @list 2>$null) | ForEach-Object { ($_ -replace "`0", '').Trim() } |
        Where-Object { $_ }
}

function Get-State {
    if ((Get-Distros) -notcontains $Name) { return 'not created' }
    if ((Get-Distros -Running) -contains $Name) { return 'running' }
    'stopped'
}

# Steps write to <file>.part and rename it when done, so make never sees half a file.
function Complete-Part {
    param([string]$Path)
    if (Test-Run "rename $Path.part to $Path") { Move-Item -Force "$Path.part" $Path }
}

function Save-Url {
    param([string]$Url, [string]$Path)
    Invoke-Change curl.exe @('-fL', '--progress-bar', '-o', "$Path.part", $Url)
    Complete-Part $Path
}

switch ($Step) {
    'download' {
        # The latest-*.txt file names the newest build: "<dir>/<file> <size>".
        $latest = (Invoke-Native curl.exe @('-fsSL', "$Mirror/latest-$Flavor.txt")) -join "`n"
        if ($latest -notmatch "(?m)^(\S+/$Flavor-\S+\.tar\.xz) ") {
            throw "No $Flavor tarball listed in $Mirror/latest-$Flavor.txt"
        }
        $url = "$Mirror/$($Matches[1])"
        $sums = (Invoke-Native curl.exe @('-fsSL', "$url.sha256")) -join "`n"
        if ($sums -notmatch '(?m)^([0-9a-f]{64}) ') { throw "No SHA256 in $url.sha256" }
        $expected = $Matches[1]

        New-Item -ItemType Directory -Force (Split-Path $Download) | Out-Null
        Write-Host "Downloading $url"
        Save-Url $url $Download
        if ($WhatIfPreference) { Write-Host "What if: check the SHA256 is $expected"; break }
        $actual = (Get-FileHash -Algorithm SHA256 $Download).Hash.ToLower()
        if ($actual -ne $expected) {
            Remove-Item $Download
            throw "SHA256 mismatch: expected $expected, got $actual"
        }
        Write-Host "SHA256 OK"
    }

    'image' {
        # Copies every entry of the stage3, keeping its owners and modes, then adds the
        # files listed in image.mtree with the owners and modes given there.
        Invoke-Change $Tar @('-cf', "$Image.part", "@$Download", '@image.mtree')
        Complete-Part $Image
    }

    'create' {
        New-Item -ItemType Directory -Force $VmDir | Out-Null
        Invoke-Change wsl.exe @('--import', $Name, $VmDir, $Image, '--version', '2')
        try {
            Invoke-Guest -Root @('--cd', $PSScriptRoot, '--', 'sh', 'guest/setup.sh')
        } catch {
            # Leave nothing half-made, so the next `make` creates the machine again.
            & wsl.exe --unregister $Name | Out-Null
            throw
        }
    }

    'start' {
        # WSL stops a distro soon after its last wsl.exe session ends, which would take
        # nginx with it, so a hidden session that only sleeps keeps it running.
        # Only a running distro is asked, since asking would start a stopped one.
        $kept = $false
        if ((Get-State) -eq 'running') {
            & wsl.exe -d $Name -u root -- pgrep -xf 'sleep infinity' | Out-Null
            $kept = $LASTEXITCODE -eq 0
        }
        $keepalive = @('-d', $Name, '-u', 'root', '--exec', 'sleep', 'infinity')
        if (-not $kept -and (Test-Run "wsl.exe $($keepalive -join ' '), hidden, in the background")) {
            Start-Process wsl.exe -WindowStyle Hidden -ArgumentList $keepalive
        }

        $wait = @('-d', $Name, '-u', 'root', '--', 'timeout', $BootTimeout,
            'systemctl', 'is-system-running', '--wait')
        if (-not (Test-Run "wsl.exe $($wait -join ' ')")) { break }
        Write-Host 'Waiting for systemd...'
        $state = (& wsl.exe @wait) -join ''
        switch ($state) {
            'running' { }
            'degraded' { Write-Host "systemd is degraded; run 'systemctl --failed' in the guest to see why." }
            default {
                & wsl.exe -d $Name -u root -- systemctl list-jobs --no-pager
                throw "systemd did not finish booting within ${BootTimeout}s (state: '$state')"
            }
        }
    }

    'provision' {
        Invoke-Guest -Root @('--cd', $PSScriptRoot, '--', 'sh', 'guest/install-ansible.sh')
        Invoke-Guest @('--cd', '/workspace', '--', 'ansible-playbook', '-e', "http_port=$HttpPort", 'playbook.yaml')
    }

    'check-config' {
        # Docker's script reads the kernel config from /proc/config.gz, which the WSL
        # kernel provides, so it checks the kernel every WSL distro shares.
        Save-Url $CheckConfigUrl 'check-config.sh'
        Invoke-Guest @('--cd', '/workspace', '--', 'bash', './check-config.sh')
    }

    'ssh' {
        if (Test-Run "wsl.exe -d $Name --cd /workspace") { & wsl.exe -d $Name --cd /workspace }
    }

    'status' {
        $state = Get-State
        if ($state -eq 'running') { $state += ", http://localhost:$HttpPort" }
        Write-Output $state
    }

    'versions' {
        $windows = [Environment]::OSVersion.Version.ToString()
        $wsl = @(& wsl.exe --version) | ForEach-Object { $_ -replace "`0", '' } |
            Where-Object { $_ -match '^WSL' } | Select-Object -First 1
        $make = @(& make --version)[0]
        $ansible = 'not installed'
        if ((Get-State) -ne 'not created') {
            $out = & wsl.exe -d $Name -- sh -c 'ansible --version 2>/dev/null | head -n 1'
            if ($out) { $ansible = $out }
        }
        '{0,-14}{1}' -f 'Windows:', $windows
        '{0,-14}{1}' -f 'WSL:', ($wsl -replace '^.*:\s*', '')
        '{0,-14}{1}' -f 'make:', ($make -replace '^GNU Make ', '')
        '{0,-14}{1}' -f 'ansible-core:', ($ansible -replace '^.*\[core ([^\]]+)\].*$', '$1')
    }

    'halt' {
        if ((Get-State) -eq 'running') {
            Invoke-Change wsl.exe @('--terminate', $Name)
        }
    }

    'destroy' {
        if ((Get-State) -ne 'not created') {
            Invoke-Change wsl.exe @('--unregister', $Name)
        }
        if (Test-Path $VmDir) { Remove-Item -Recurse -Force $VmDir }
    }

    'purge' {
        $dir = Split-Path $Download
        if (Test-Path $dir) { Remove-Item -Recurse -Force $dir } else { 'No downloaded image to remove.' }
    }
}
