$email = "mi130830@gmail.com"
$apiKey = "b3228559bdada32277eaf41ca962abd6ecc4b"
$accountId = "bf0c3f16fe007c895fcd492634065a1f"

$headers = @{
    "X-Auth-Email" = $email
    "X-Auth-Key"   = $apiKey
    "Content-Type" = "application/json"
}

Write-Host "--- Inspecting Device Settings ---"
$settingsUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/devices/settings"
try {
    $res = Invoke-RestMethod -Uri $settingsUri -Method Get -Headers $headers
    if ($res.success) {
        Write-Host ($res.result | ConvertTo-Json -Depth 5)
    }
    else {
        Write-Host "Failed to get settings"
    }
}
catch { Write-Host "Error: $_" }

Write-Host "`n--- Inspecting Access Apps (Looking for Enrollment/Auth) ---"
$appsUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/access/apps"
try {
    $res = Invoke-RestMethod -Uri $appsUri -Method Get -Headers $headers
    if ($res.success) {
        foreach ($app in $res.result) {
            Write-Host "App: $($app.name) (Type: $($app.type))"
            Write-Host "  UID: $($app.uid)"
            Write-Host "  Domain: $($app.domain)"
            
            # If it looks like 'warp' or 'enrollment', fetch its policies
            $policiesUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/access/apps/$($app.uid)/policies"
            try {
                $polRes = Invoke-RestMethod -Uri $policiesUri -Method Get -Headers $headers
                Write-Host "  Policies: $($polRes.result.Count)"
                foreach ($pol in $polRes.result) {
                    Write-Host "    - $($pol.name) (Decision: $($pol.decision))"
                    Write-Host "      Include: $($pol.include | ConvertTo-Json -Depth 1 -Compress)"
                }
            }
            catch { Write-Host "    Error fetching policies" }
            Write-Host "----------------"
        }
    }
}
catch { Write-Host "Error: $_" }
