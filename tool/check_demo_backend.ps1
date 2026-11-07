$ErrorActionPreference = 'Stop'
$demoRoot = Split-Path -Parent $PSScriptRoot
$demoConfig = Get-Content -LiteralPath (Join-Path $demoRoot 'assets/supabase.public.json') -Raw | ConvertFrom-Json
$demoValues = @{}
$demoEnvPath = Join-Path $demoRoot '.env'
if (Test-Path -LiteralPath $demoEnvPath) {
    foreach ($line in Get-Content -LiteralPath $demoEnvPath) {
        if ($line -match '^\s*([A-Z_]+)\s*=(.*)$') {
            $demoValues[$Matches[1]] = $Matches[2].Trim().Trim([char]34, [char]39)
        }
    }
}
$demoUrl = $demoConfig.url
$demoKey = $demoConfig.publicKey
if ($demoValues['SUPABASE_URL']) { $demoUrl = $demoValues['SUPABASE_URL'] }
if ($demoValues['SUPABASE_ANON_KEY']) { $demoKey = $demoValues['SUPABASE_ANON_KEY'] }
if ($demoValues['SUPABASE_PUBLISHABLE_KEY']) { $demoKey = $demoValues['SUPABASE_PUBLISHABLE_KEY'] }
if (!$demoUrl -or !$demoKey) { throw 'No public backend configuration is available.' }
$demoHeaders = @{ apikey = $demoKey }
if ($demoKey.StartsWith('eyJ')) { $demoHeaders.Authorization = 'Bearer ' + $demoKey }
$demoResults = [System.Collections.Generic.List[object]]::new()
foreach ($demoEndpoint in @('/auth/v1/settings', '/rest/v1/vehicles?select=id&limit=1', '/rest/v1/obd_recording_sessions?select=id&limit=1', '/rest/v1/obd_recording_samples?select=sample_id&limit=1', '/rest/v1/profiles?select=id&limit=1')) {
    try {
        $demoResponse = Invoke-WebRequest -Uri ($demoUrl.TrimEnd('/') + $demoEndpoint) -Headers $demoHeaders -UseBasicParsing -TimeoutSec 20
        if ($demoEndpoint.StartsWith('/auth/')) {
            $demoSettings = $demoResponse.Content | ConvertFrom-Json
            $demoDetail = 'Email/password enabled: ' + [string]$demoSettings.external.email + '; email autoconfirm: ' + [string]$demoSettings.mailer_autoconfirm + '; signup disabled: ' + [string]$demoSettings.disable_signup
            $demoPass = $demoSettings.external.email -eq $true
        } else {
            $demoRows = @($demoResponse.Content | ConvertFrom-Json)
            $demoPass = $demoResponse.Content.Trim() -eq '[]'
            $demoDetail = if ($demoPass) { 'Anonymous read exposes no account rows.' } else { 'FAIL: anonymous read returned rows.' }
        }
        $demoResults.Add([PSCustomObject]@{ endpoint = $demoEndpoint; status = [int]$demoResponse.StatusCode; pass = $demoPass; detail = $demoDetail })
    } catch {
        $demoDenied = $_.Exception.Response -and ([int]$_.Exception.Response.StatusCode -in @(401, 403))
        $demoResults.Add([PSCustomObject]@{ endpoint = $demoEndpoint; pass = ($demoDenied -and $demoEndpoint.StartsWith('/rest/')); detail = if ($demoDenied) { 'Anonymous access rejected. Authenticated schema access still requires a test account.' } else { $_.Exception.Message } })
    }
}
# A synthetic nonexistent user checks the live password endpoint without creating
# accounts, sending emails, or touching any existing user's credentials/data.
try {
    $demoBody = @{ email = ('demo-audit-' + [guid]::NewGuid().ToString('N') + '@example.invalid'); password = [guid]::NewGuid().ToString('N') } | ConvertTo-Json
    $null = Invoke-WebRequest -Uri ($demoUrl.TrimEnd('/') + '/auth/v1/token?grant_type=password') -Headers $demoHeaders -Method Post -ContentType 'application/json' -Body $demoBody -UseBasicParsing -TimeoutSec 20
    $demoResults.Add([PSCustomObject]@{ endpoint = 'password rejection'; pass = $false; detail = 'Unexpected authentication success.' })
} catch {
    $demoError = $null
    try { $demoError = $_.ErrorDetails.Message | ConvertFrom-Json } catch { }
    $demoResults.Add([PSCustomObject]@{ endpoint = 'password rejection'; pass = ($demoError.error_code -eq 'invalid_credentials' -or $demoError.code -eq 'invalid_credentials'); detail = $demoError.msg; code = $demoError.error_code })
}
$demoResults | ConvertTo-Json -Depth 4
if (@($demoResults | Where-Object { !$_.pass }).Count -gt 0) { exit 1 }
