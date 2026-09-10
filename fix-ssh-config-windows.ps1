# Fix broken XO-1 Host block in Windows OpenSSH 9.5+ config.
# Run in PowerShell:
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\fix-ssh-config-windows.ps1
#
# Backs up %USERPROFILE%\.ssh\config, removes any Host block matching 10.0.0.25 / xo1,
# and appends a corrected block (no ssh-dss; one "+" per algorithm line).

$ErrorActionPreference = 'Stop'
$configDir = Join-Path $env:USERPROFILE '.ssh'
$configPath = Join-Path $configDir 'config'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "$configPath.bak-$stamp"

$newBlock = @'
Host xo1 olpc-xo1 10.0.0.25
    HostName 10.0.0.25
    User olpc
    IdentityFile ~/.ssh/id_rsa_olpc
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    KexAlgorithms +diffie-hellman-group-exchange-sha256,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1
    Ciphers +aes128-ctr,aes256-ctr,aes128-cbc,aes256-cbc
    MACs +hmac-sha2-256,hmac-sha1
    StrictHostKeyChecking accept-new
'@

if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
}

if (Test-Path $configPath) {
    Copy-Item $configPath $backupPath
    Write-Host "Backed up to $backupPath"
    $lines = Get-Content $configPath
} else {
    $lines = @()
    Write-Host "No existing config; creating $configPath"
}

$out = New-Object System.Collections.Generic.List[string]
$skip = $false
$hostRe = [regex]'^\s*Host\s+'

foreach ($line in $lines) {
    if ($hostRe.IsMatch($line)) {
        if ($line -match '10\.0\.0\.25|\bxo1\b|\bolpc-xo1\b') {
            $skip = $true
            continue
        }
        $skip = $false
    }
    if ($skip) {
        if ($line -match '^\s*\S') {
            continue
        }
        $skip = $false
    }
    $out.Add($line)
}

if ($out.Count -gt 0 -and $out[$out.Count - 1] -ne '') {
    $out.Add('')
}
$out.Add($newBlock)

Set-Content -Path $configPath -Value $out -Encoding utf8
Write-Host "Wrote corrected XO-1 block to $configPath"
Write-Host "Test: ssh xo1"
