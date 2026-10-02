param(
    [string]$AppDirectory = (Join-Path $env:LOCALAPPDATA 'ValuatumMail')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$AppDirectory = [System.IO.Path]::GetFullPath($AppDirectory)
$python = Join-Path $AppDirectory 'venv\Scripts\python.exe'
$runtime = Join-Path $AppDirectory 'runtime.py'
if (-not (Test-Path -LiteralPath $python) -or -not (Test-Path -LiteralPath $runtime)) {
    throw 'Install Valuatum Mail before configuring your account.'
}
$userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = Get-Acl -LiteralPath $AppDirectory
$acl.SetAccessRuleProtection($true, $false)
foreach ($rule in @($acl.Access)) { $acl.RemoveAccessRuleSpecific($rule) }
foreach ($sid in @($userSid, (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')))) {
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')))
}
$directoryInfo = New-Object System.IO.DirectoryInfo($AppDirectory)
if ($directoryInfo.PSObject.Methods['SetAccessControl']) { $directoryInfo.SetAccessControl($acl) }
else { [System.IO.FileSystemAclExtensions]::SetAccessControl($directoryInfo, $acl) }

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Valuatum Mail setup'
$form.ClientSize = New-Object System.Drawing.Size(440, 250)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$intro = New-Object System.Windows.Forms.Label
$intro.Text = 'Enter your own Valuatum email account and password.'
$intro.SetBounds(20, 18, 400, 24)
$form.Controls.Add($intro)
$accountLabel = New-Object System.Windows.Forms.Label
$accountLabel.Text = 'Email address'
$accountLabel.SetBounds(20, 53, 120, 20)
$form.Controls.Add($accountLabel)
$account = New-Object System.Windows.Forms.TextBox
$account.SetBounds(20, 76, 400, 25)
$form.Controls.Add($account)
$passwordLabel = New-Object System.Windows.Forms.Label
$passwordLabel.Text = 'Password'
$passwordLabel.SetBounds(20, 112, 120, 20)
$form.Controls.Add($passwordLabel)
$password = New-Object System.Windows.Forms.TextBox
$password.UseSystemPasswordChar = $true
$password.SetBounds(20, 135, 400, 25)
$form.Controls.Add($password)
$status = New-Object System.Windows.Forms.Label
$status.SetBounds(20, 169, 400, 34)
$form.Controls.Add($status)
$save = New-Object System.Windows.Forms.Button
$save.Text = 'Verify and save'
$save.SetBounds(200, 210, 125, 28)
$form.Controls.Add($save)
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancel'
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$cancel.SetBounds(335, 210, 85, 28)
$form.Controls.Add($cancel)
$form.AcceptButton = $save
$form.CancelButton = $cancel

$configPath = Join-Path $AppDirectory 'config.json'
$settings = [ordered]@{
    account = ''; host = 'mail.valuatum.com'; imap_port = 993; smtp_port = 465
    drafts_folder = 'INBOX.Drafts'; sent_folder = 'INBOX.Sent'
}
if (Test-Path -LiteralPath $configPath) {
    $existing = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    foreach ($key in @($settings.Keys)) {
        if ($null -ne $existing.$key) { $settings[$key] = $existing.$key }
    }
    $account.Text = $settings.account
}

$save.Add_Click({
    if ([string]::IsNullOrWhiteSpace($account.Text) -or $password.Text.Length -eq 0) {
        $status.Text = 'Enter an email address and password.'
        return
    }
    $save.Enabled = $false
    $cancel.Enabled = $false
    $status.Text = 'Verifying your IMAP login...'
    $form.Refresh()
    $candidateDirectory = Join-Path $AppDirectory ('configure-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $candidateDirectory | Out-Null
        $settings.account = $account.Text.Trim()
        $settings | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $candidateDirectory 'config.json') -Encoding UTF8
        $securePassword = ConvertTo-SecureString -String $password.Text -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($settings.account, $securePassword)
        $credential | Export-Clixml -LiteralPath (Join-Path $candidateDirectory 'credential.xml')
        # Passwords are DPAPI-protected in the candidate file, never process arguments.
        $savedEnvironment = @{}
        foreach ($variable in Get-ChildItem Env: | Where-Object { $_.Name -match '^VALUATUM_(MAIL_|IMAP_|SMTP_|DRAFTS_|SENT_)|^MAIL_BRIDGE_' }) {
            $savedEnvironment[$variable.Name] = $variable.Value
            Remove-Item -LiteralPath ('Env:\' + $variable.Name)
        }
        try {
            & $python $runtime --check --config-dir $candidateDirectory *> $null
            $checkExitCode = $LASTEXITCODE
        }
        finally {
            foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
        }
        if ($checkExitCode -ne 0) {
            $status.Text = 'Login failed. Check your details or connection, then retry.'
            return
        }
        Copy-Item -LiteralPath (Join-Path $candidateDirectory 'credential.xml') -Destination (Join-Path $AppDirectory 'credential.xml') -Force
        Copy-Item -LiteralPath (Join-Path $candidateDirectory 'config.json') -Destination $configPath -Force
        $password.Clear()
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    }
    catch {
        $status.Text = 'Setup failed. Check your connection and access, then retry.'
    }
    finally {
        if (Test-Path -LiteralPath $candidateDirectory) {
            foreach ($name in @('config.json', 'credential.xml')) {
                $candidateFile = Join-Path $candidateDirectory $name
                if (Test-Path -LiteralPath $candidateFile) { Remove-Item -LiteralPath $candidateFile -Force }
            }
            Remove-Item -LiteralPath $candidateDirectory -Force
        }
        $save.Enabled = $true
        $cancel.Enabled = $true
    }
})

$result = $form.ShowDialog()
$form.Dispose()
if ($result -ne [System.Windows.Forms.DialogResult]::OK) { exit 1 }
Write-Host 'Account verified and saved for this Windows user.'
