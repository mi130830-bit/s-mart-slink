$email = "Mi130830@gmail.com"
$apiKey = "b3228559bdada32277eaf41ca962abd6ecc4b"
$accountId = "bf0c3f16fe007c895fcd492634065a1f" # From previous output

$headers = @{
    "X-Auth-Email" = $email
    "X-Auth-Key"   = $apiKey
    "Content-Type" = "application/json"
}

try {
    Write-Host "Checking Account ID: $accountId"
    
    # 1. Get Device Enrollment Policies
    # Using the 'include' endpoint for enrollment permissions
    $enrollmentUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/devices/policy"
    
    try {
        $response = Invoke-RestMethod -Uri $enrollmentUri -Method Get -Headers $headers
        
        if ($response.success) {
            Write-Host "✅ Enrollment Policies Found:"
            foreach ($policy in $response.result) {
                Write-Host "   - Name: $($policy.name)"
                Write-Host "     Enabled: $($policy.enabled)"
                if ($policy.include) {
                    Write-Host "     Allowed Groups/Emails:"
                    foreach ($rule in $policy.include) {
                        Write-Host "       - $($rule | ConvertTo-Json -Depth 1 -Compress)"
                    }
                }
            }
        }
        else {
            Write-Host "❌ Failed to get enrollment policies."
            Write-Host $response.errors[0].message
        }
    }
    catch {
        Write-Host "Error fetching enrollment policies: $_"
        # Try fallback to access groups if specific endpoint fails
    }

}
catch {
    Write-Host "Fatal Error: $_"
}
