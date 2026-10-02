param(
    [ValidateSet('codex', 'claude', 'both')]
    [string]$Clients = 'codex',
    [switch]$SkipConfigure,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$appDirectory = Join-Path $env:LOCALAPPDATA 'ValuatumMail'
$venvPython = Join-Path $appDirectory 'venv\Scripts\python.exe'
$runtime = Join-Path $appDirectory 'runtime.py'

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Executable (exit $LASTEXITCODE)" }
}

function Test-MailLogin {
    $savedEnvironment = @{}
    foreach ($variable in Get-ChildItem Env: | Where-Object { $_.Name -match '^VALUATUM_(MAIL_|IMAP_|SMTP_|DRAFTS_|SENT_)|^MAIL_BRIDGE_' }) {
        $savedEnvironment[$variable.Name] = $variable.Value
        Remove-Item -LiteralPath ('Env:\' + $variable.Name)
    }
    try {
        & $venvPython $runtime --check --config-dir $appDirectory *> $null
        if ($LASTEXITCODE -ne 0) { throw 'Mail login check failed. Run the installed configure.ps1 to retry account setup.' }
    }
    finally {
        foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    }
}

if ($CheckOnly) {
    foreach ($file in @($venvPython, $runtime, (Join-Path $appDirectory 'config.json'), (Join-Path $appDirectory 'credential.xml'))) {
        if (-not (Test-Path -LiteralPath $file)) { throw 'Installation or account setup is incomplete. Run install.ps1 first.' }
    }
    Test-MailLogin
    Write-Host 'Valuatum Mail login verified.'
    exit 0
}

$pythonCommand = $null
$pythonArguments = @()
foreach ($candidate in @('py', 'python')) {
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($null -eq $command) { continue }
    $arguments = @()
    if ($candidate -eq 'py') { $arguments = @('-3') }
    & $command.Source @arguments -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' *> $null
    if ($LASTEXITCODE -eq 0) {
        $pythonCommand = $command.Source
        $pythonArguments = $arguments
        break
    }
}
if ($null -eq $pythonCommand) { throw 'Python 3.10 or newer is required. Install Python for Windows, then rerun this script.' }

$selectedClients = @($Clients)
if ($Clients -eq 'both') { $selectedClients = @('codex', 'claude') }
$clientCommands = @{}
foreach ($client in $selectedClients) {
    $command = Get-Command $client -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        if ($client -eq 'claude') { throw 'Claude Code CLI is required for -Clients claude. Claude Desktop is not registered by this installer.' }
        throw 'Codex CLI is required. Install it before running this installer.'
    }
    $clientCommands[$client] = $command.Source
}

$packageFiles = @('runtime.py', 'mail_server.py', 'requirements.txt', 'configure.ps1')
foreach ($file in $packageFiles + @('.agents\skills\valuatum-mail\SKILL.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) { throw "Package file is missing: $file" }
}
New-Item -ItemType Directory -Path $appDirectory -Force | Out-Null
$userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = Get-Acl -LiteralPath $appDirectory
$acl.SetAccessRuleProtection($true, $false)
foreach ($rule in @($acl.Access)) { $acl.RemoveAccessRuleSpecific($rule) }
foreach ($sid in @($userSid, (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')))) {
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')))
}
$directoryInfo = New-Object System.IO.DirectoryInfo($appDirectory)
if ($directoryInfo.PSObject.Methods['SetAccessControl']) { $directoryInfo.SetAccessControl($acl) }
else { [System.IO.FileSystemAclExtensions]::SetAccessControl($directoryInfo, $acl) }
foreach ($file in $packageFiles) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $appDirectory $file) -Force
}
if (-not (Test-Path -LiteralPath $venvPython)) {
    Invoke-Checked -Executable $pythonCommand -Arguments ($pythonArguments + @('-m', 'venv', (Join-Path $appDirectory 'venv')))
}
Invoke-Checked -Executable $venvPython -Arguments @('-m', 'pip', 'install', '-r', (Join-Path $appDirectory 'requirements.txt'))

if (-not $SkipConfigure) {
    if ((Test-Path -LiteralPath (Join-Path $appDirectory 'config.json')) -and (Test-Path -LiteralPath (Join-Path $appDirectory 'credential.xml'))) {
        Write-Host 'Existing account settings preserved. Run the installed configure.ps1 to change them.'
    }
    else {
        $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Invoke-Checked -Executable $powershell -Arguments @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $appDirectory 'configure.ps1'), '-AppDirectory', $appDirectory)
    }
    Test-MailLogin
}

foreach ($client in $selectedClients) {
    $cli = $clientCommands[$client]
    & $cli mcp get valuatum_mail *> $null
    $alreadyRegistered = $LASTEXITCODE -eq 0
    if ($alreadyRegistered) {
        Write-Host "Existing $client valuatum_mail registration preserved; its command was not changed. Use '$client mcp get valuatum_mail' to check its path."
    }
    elseif ($client -eq 'codex') {
        Invoke-Checked -Executable $cli -Arguments @('mcp', 'add', 'valuatum_mail', '--', $venvPython, $runtime)
    }
    else {
        Invoke-Checked -Executable $cli -Arguments @('mcp', 'add', '--scope', 'user', '--transport', 'stdio', 'valuatum_mail', '--', $venvPython, $runtime)
    }
}

$skillRoots = @((Join-Path $env:USERPROFILE '.agents\skills'))
if ($selectedClients -contains 'claude') { $skillRoots += Join-Path $env:USERPROFILE '.claude\skills' }
foreach ($skillRoot in $skillRoots) {
    $destination = Join-Path $skillRoot 'valuatum-mail'
    if (Test-Path -LiteralPath $destination) {
        Write-Host "Existing skill preserved: $destination"
        continue
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '.agents\skills\valuatum-mail\SKILL.md') -Destination (Join-Path $destination 'SKILL.md')
}
Write-Host "Files installed in $appDirectory. Restart the selected client to load Valuatum Mail."
if ($SkipConfigure) { Write-Host "Account setup was skipped; mail access is not verified. Set up your account by running: & '$appDirectory\configure.ps1'" }
else { Write-Host 'Mail login verified.' }
