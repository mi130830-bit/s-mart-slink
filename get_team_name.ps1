$email = "Mi130830@gmail.com"
$apiKey = "b3228559bdada32277eaf41ca962abd6ecc4b"

$headers = @{
    "X-Auth-Email" = $email
    "X-Auth-Key"   = $apiKey
    "Content-Type" = "application/json"
}

try {
    # 1. Get Accounts
    $accountsUri = "https://api.cloudflare.com/client/v4/accounts"
    $accountsResponse = Invoke-RestMethod -Uri $accountsUri -Method Get -Headers $headers
    
    if ($accountsResponse.success) {
        foreach ($account in $accountsResponse.result) {
            $accountId = $account.id
            $accountName = $account.name
            
            Write-Host "Checking Account: $accountName ($accountId)"

            # 2. Get Access Organization (Team Name)
            $orgUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/access/organizations"
            try {
                $orgResponse = Invoke-RestMethod -Uri $orgUri -Method Get -Headers $headers
                
                if ($orgResponse.success -and $orgResponse.result) {
                    $teamName = $orgResponse.result.name
                    $authDomain = $orgResponse.result.auth_domain
                    
                    Write-Host "---------------------------------------------------"
                    Write-Host "✅ FOUND TEAM NAME: $teamName"
                    Write-Host "   URL: https://$authDomain"
                    Write-Host "---------------------------------------------------"
                }
                else {
                    Write-Host "   No Zero Trust organization found for this account."
                }
            }
            catch {
                Write-Host "   Error fetching organization: $_"
            }
        }
    }
    else {
        Write-Host "Failed to retrieve accounts."
    }
}
catch {
    Write-Host "Error: $_"
}
