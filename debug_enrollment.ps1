$email = "mi130830@gmail.com"
$apiKey = "b3228559bdada32277eaf41ca962abd6ecc4b"
$accountId = "bf0c3f16fe007c895fcd492634065a1f"

$headers = @{
    "X-Auth-Email" = $email
    "X-Auth-Key"   = $apiKey
    "Content-Type" = "application/json"
}

function Test-Endpoint ($path) {
    $uri = "https://api.cloudflare.com/client/v4/accounts/$accountId/$path"
    Write-Host "Testing: $path"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        if ($response.success) {
            Write-Host "✅ SUCCESS"
            # Write-Host ($response.result | ConvertTo-Json -Depth 2)
            return $true
        }
        else {
            Write-Host "❌ FAILED: $($response.errors[0].message)"
            return $false
        }
    }
    catch {
        Write-Host "⚠️ ERROR: $_"
        return $false
    }
}

Write-Host "--- Debugging Enrollment Endpoints ---"

# Try candidate endpoints for Device Enrollment
Test-Endpoint "devices/enroll_rules"
Test-Endpoint "devices/rules"
Test-Endpoint "devices/settings"
Test-Endpoint "access/users"
Test-Endpoint "devices/policies" # We know this is Split Tunnel but maybe valid for listing?
Test-Endpoint "access/groups"

