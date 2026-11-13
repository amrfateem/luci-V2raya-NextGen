# SPDX-License-Identifier: GPL-3.0-only
#
# LAN-client test for the v2rayA NextGen router. Run it on a Windows machine
# on the router's LAN. It drives the v2rayA API and checks what a LAN client
# actually sees: exit IP, ping, DNS, and the firewall state on the router.
#
# Requires PuTTY's plink.exe and these environment variables:
#   V2RAYA_ROUTER_PASSWORD   root password of the router (not stored here)
#
# Usage:
#   $env:V2RAYA_ROUTER_PASSWORD = '...'
#   .\tests\lan-client-test.ps1 -HostKey 'SHA256:...'
#
# The script restores the service and DNS hijack settings it changes.
# Exits non-zero if any check fails.

[CmdletBinding()]
param(
    [string]$Router = '10.0.0.1',
    [string]$User = 'root',
    [string]$ApiUser = 'amrfateem',
    [Parameter(Mandatory = $true)][string]$HostKey,
    [string]$Plink = 'C:\Program Files\PuTTY\plink.exe'
)

$ErrorActionPreference = 'Stop'
$pass = 0
$fail = 0
$api = "http://${Router}:2017/api"
$password = $env:V2RAYA_ROUTER_PASSWORD
if (-not $password) { throw 'Set V2RAYA_ROUTER_PASSWORD first.' }

function Ok($text)  { $script:pass++; Write-Output "PASS  $text" }
function Bad($text) { $script:fail++; Write-Output "FAIL  $text" }
function Check($text, [bool]$condition) { if ($condition) { Ok $text } else { Bad $text } }

function Invoke-Router([string]$command) {
    $file = [IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $file -Value $command -Encoding ASCII
        $plinkArgs = @('-ssh', '-batch', '-hostkey', $HostKey, '-pw', $password, '-m', $file, "$User@$Router")
        (& $Plink @plinkArgs 2>&1 | Out-String).Trim()
    } finally {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
    }
}

function Get-JwtSecret {
    $hex = Invoke-Router "sqlite3 /etc/v2raya/v2raya.db `"select value from system_config where key='system:jwtSecret';`""
    $hex = $hex.Trim().Trim('"')
    if ($hex -notmatch '^[0-9a-fA-F]{64}$') { throw 'Unexpected jwtSecret format on the router.' }
    $bytes = New-Object byte[] 32
    for ($i = 0; $i -lt 32; $i++) { $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
    return $bytes
}

function ConvertTo-Base64Url([byte[]]$bytes) {
    [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-ApiHeaders {
    $secret = Get-JwtSecret
    $header = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
    $exp = [int][double]::Parse((Get-Date -UFormat %s)) + 3600
    $payload = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes(('{"uname":"' + $ApiUser + '","exp":' + $exp + '}')))
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $secret
    $sig = ConvertTo-Base64Url ($hmac.ComputeHash([Text.Encoding]::ASCII.GetBytes("$header.$payload")))
    return @{ Authorization = "$header.$payload.$sig"; 'Content-Type' = 'application/json' }
}

function Set-Setting($headers, $body) {
    Invoke-RestMethod -Method Put -Headers $headers -Uri "$api/setting" -Body ($body | ConvertTo-Json -Compress) -TimeoutSec 30 | Out-Null
}

function Client-ExitIp { (& curl.exe --noproxy '*' -4 -sS --max-time 15 https://ipinfo.io/ip 2>$null | Out-String).Trim() }
function Router-ProxyIp { (Invoke-Router 'curl -4 -sS --max-time 15 https://ipinfo.io/ip') }
function Router-DirectIp { (Invoke-Router 'curl -4 -sS --max-time 15 --interface wan https://ipinfo.io/ip') }
function Client-Ping { (& ping.exe -n 2 1.1.1.1 2>$null | Out-String) -match 'Received = 2' }
function Client-Dns { try { [bool](Resolve-DnsName -Name openwrt.org -Server $Router -Type A -QuickTimeout -ErrorAction Stop) } catch { $false } }
function Router-Tables { Invoke-Router 'nft list tables' }
function Wait-Seconds([int]$n) { Start-Sleep -Seconds $n }

Write-Output '== setup'
$headers = New-ApiHeaders
$originalDns = (Invoke-Router "sqlite3 /etc/v2raya/v2raya.db `"select value from system_config where key='system:setting';`"") -replace '.*"dnsHijack":"([^"]*)".*', '$1'
$originalDns = if ($originalDns -match '^(yes|no)$') { $originalDns } else { 'no' }
Write-Output "      original dnsHijack=$originalDns"

try {
    Write-Output '== proxy running'
    Invoke-RestMethod -Method Post -Headers $headers -Uri "$api/v2ray" -TimeoutSec 60 | Out-Null
    Wait-Seconds 30
    $proxyIp = Router-ProxyIp
    $directIp = Router-DirectIp
    Check 'router sees a proxy exit IP' ([bool]$proxyIp)
    Check 'proxy and direct exit IPs differ' ($proxyIp -ne $directIp)
    Check 'LAN client exits through the proxy' ((Client-ExitIp) -eq $proxyIp)
    Check 'LAN client can ping 1.1.1.1' (Client-Ping)
    Check 'LAN client resolves via router' (Client-Dns)

    Write-Output '== proxy stopped'
    Invoke-RestMethod -Method Delete -Headers $headers -Uri "$api/v2ray" -TimeoutSec 60 | Out-Null
    Wait-Seconds 5
    Check 'LAN client exits direct after stop' ((Client-ExitIp) -eq $directIp)
    Check 'LAN client can ping 1.1.1.1 after stop' (Client-Ping)
    Check 'LAN client resolves after stop' (Client-Dns)
    $tables = Router-Tables
    Check 'router has no inet v2raya table after stop' (-not ($tables -match 'table inet v2raya\b'))
    Check 'router still has inet fw4 with masquerade' (((Invoke-Router 'nft list table inet fw4') -match 'masquerade'))

    Write-Output '== DNS hijack on'
    Set-Setting $headers @{ dnsHijack = 'yes' }
    Invoke-RestMethod -Method Post -Headers $headers -Uri "$api/v2ray" -TimeoutSec 60 | Out-Null
    Wait-Seconds 30
    Check 'router has inet v2raya_dns while hijack is on' ((Router-Tables) -match 'v2raya_dns')
    Check 'LAN client resolves with hijack on' (Client-Dns)

    Write-Output '== DNS hijack on, proxy stopped'
    Invoke-RestMethod -Method Delete -Headers $headers -Uri "$api/v2ray" -TimeoutSec 60 | Out-Null
    Wait-Seconds 5
    Check 'router has no v2raya_dns table after stop' (-not ((Router-Tables) -match 'v2raya_dns'))
    Check 'LAN client resolves after stop with hijack on' (Client-Dns)
}
finally {
    Write-Output '== restore'
    Set-Setting $headers @{ dnsHijack = $originalDns }
    Invoke-RestMethod -Method Post -Headers $headers -Uri "$api/v2ray" -TimeoutSec 60 | Out-Null
    Wait-Seconds 30
    Check 'proxy running after restore' ((Client-ExitIp) -eq (Router-ProxyIp))
}

Write-Output ''
Write-Output "RESULT: $pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
