$email = "mi130830@gmail.com"
$apiKey = "b3228559bdada32277eaf41ca962abd6ecc4b"
$accountId = "bf0c3f16fe007c895fcd492634065a1f"

$headers = @{
    "X-Auth-Email" = $email
    "X-Auth-Key"   = $apiKey
    "Content-Type" = "application/json"
}

Write-Host "Searching for WARP/Enrollment Access App..."

# List Access Apps
$appsUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/access/apps"
try {
    $res = Invoke-RestMethod -Uri $appsUri -Method Get -Headers $headers
    
    if ($res.success) {
        $warpApp = $res.result | Where-Object { $_.type -eq "warp" -or $_.name -like "*WARP*" }
        
        if ($warpApp) {
            Write-Host "✅ FOUND WARP APP:"
            Write-Host "   Name: $($warpApp.name)"
            Write-Host "   UID: $($warpApp.uid)"
            Write-Host "   Type: $($warpApp.type)"
            
            # Now allow the user
            $appId = $warpApp.uid
            $policyUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/access/apps/$appId/policies"
            
            # Create new policy
            $policyBody = @{
                "name"     = "Allow Admin (Auto)"
                "decision" = "allow"
                "include"  = @(
                    @{ "email" = "mi130830@gmail.com" }
                )
            } | ConvertTo-Json -Depth 10

            Write-Host "   👉 Adding 'Allow Admin' policy..."
            try {
                $polRes = Invoke-RestMethod -Uri $policyUri -Method Post -Headers $headers -Body $policyBody
                if ($polRes.success) {
                    Write-Host "   ✅ SUCCESS! You should be able to login now."
                }
                else {
                    Write-Host "   ❌ Failed to add policy: $($polRes.errors[0].message)"
                }
            }
            catch {
                Write-Host "   Error adding policy: $_"
            }

        }
        else {
            Write-Host "❌ Could not find an app with type 'warp'. Listing all apps:"
            foreach ($app in $res.result) {
                Write-Host "   - $($app.name) (Type: $($app.type))"
            }
        }
    }
}
catch {
    Write-Host "Error: $_"
}
