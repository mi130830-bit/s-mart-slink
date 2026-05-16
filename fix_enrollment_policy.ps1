$email = "Mi130830@gmail.com"
$apiKey = "b3228559bdada32277eaf41ca962abd6ecc4b"
$accountId = "bf0c3f16fe007c895fcd492634065a1f"

$headers = @{
    "X-Auth-Email" = $email
    "X-Auth-Key"   = $apiKey
    "Content-Type" = "application/json"
}

Write-Host "Fixing Enrollment Policy for Account: $accountId"
$policyUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/devices/policy"

# 1. Check existing policies
try {
    $currentPolicies = Invoke-RestMethod -Uri $policyUri -Method Get -Headers $headers
    
    if ($currentPolicies.success -and $currentPolicies.result.Count -gt 0) {
        $policyId = $currentPolicies.result[0].id
        Write-Host "Found existing policy ID: $policyId. Updating..."
        
        $updateUri = "$policyUri/$policyId"
        
        # Correct Payload: usage of 'include' array
        $body = @{
            "name"    = "Allow Admin"
            "enabled" = $true
            "match"   = "any" 
            "include" = @(
                @{ "email" = "Mi130830@gmail.com" }
            )
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $updateUri -Method Put -Headers $headers -Body $body
    }
    else {
        Write-Host "No policies found. Creating new one..."
        
        $body = @{
            "name"    = "Allow Admin"
            "enabled" = $true
            "match"   = "any"
            "include" = @(
                @{ "email" = "Mi130830@gmail.com" }
            )
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $policyUri -Method Post -Headers $headers -Body $body
    }

    if ($response.success) {
        Write-Host "✅ Policy Updated Successfully!"
        Write-Host "   User 'Mi130830@gmail.com' is now allowed."
        Write-Host "   👉 Try logging into WARP again now."
    }
    else {
        Write-Host "❌ Failed: $($response.errors[0].message)"
    }
}
catch {
    Write-Host "Error: $_"
    if ($_.Exception.Response) {
        Write-Host "API returned error status."
    }
}
