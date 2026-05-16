
# Cloudflare DDNS Updater for Windows
# Reference: https://github.com/fire1ce/DDNS-Cloudflare-PowerShell
# --- CONFIGURATION (FILL THESE IN) ---
$zoneName = "namecheap.work"        # Your Domain
$recordName = "possb.namecheap.work"  # Your Subdomain
$email = "Mi130830@gmail.com"       # Your Cloudflare Email
$apiKey = "b3228559bdada32277eaf41ca962abd6ecc4b" # Cloudflare Global API Key
# Note: Get API Key from https://dash.cloudflare.com/profile/api-tokens
# -------------------------------------

$authHeader = @{
    "X-Auth-Email" = $email
    "X-Auth-Key"   = $apiKey
    "Content-Type" = "application/json"
}

# 1. Get Current Public IP
try {
    $ip = Invoke-RestMethod -Uri "https://api.ipify.org"
    Write-Host "Current Public IP: $ip" -ForegroundColor Green
}
catch {
    Write-Error "Failed to get public IP."
    exit
}

# 2. Get Zone ID
try {
    $zoneUrl = "https://api.cloudflare.com/client/v4/zones?name=$zoneName"
    $zoneResponse = Invoke-RestMethod -Uri $zoneUrl -Method Get -Headers $authHeader
    $zoneId = $zoneResponse.result[0].id
    Write-Host "Zone ID: $zoneId" -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to get Zone ID. Check API Key/Zone Name."
    exit
}

# 3. Get Record ID (for the subdomain)
try {
    $recordUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?name=$recordName"
    $recordResponse = Invoke-RestMethod -Uri $recordUrl -Method Get -Headers $authHeader
    
    if ($recordResponse.result.Count -eq 0) {
        Write-Host "Record '$recordName' not found. Creating new one..." -ForegroundColor Yellow
        $createUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records"
        $body = @{
            type    = "A"
            name    = $recordName
            content = $ip
            ttl     = 1  # Auto
            proxied = $false # IMPORTANT: Must be false for direct TCP/MySQL
        } | ConvertTo-Json
        
        $createResponse = Invoke-RestMethod -Uri $createUrl -Method Post -Headers $authHeader -Body $body
        if ($createResponse.success) {
            Write-Host "SUCCESS: Created $recordName -> $ip" -ForegroundColor Green
        }
        else {
            Write-Error "Failed to create record: $($createResponse.errors[0].message)"
        }
        exit
    }

    $recordId = $recordResponse.result[0].id
    $currentIp = $recordResponse.result[0].content
    Write-Host "Record ID: $recordId (Current: $currentIp)" -ForegroundColor Cyan

    # 4. Update Record if IP changed
    if ($currentIp -ne $ip) {
        Write-Host "IP changed ($currentIp -> $ip). Updating..." -ForegroundColor Yellow
        $updateUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId"
        $body = @{
            type    = "A"
            name    = $recordName
            content = $ip
            ttl     = 1
            proxied = $false # IMPORTANT: Must be false
        } | ConvertTo-Json
        
        $updateResponse = Invoke-RestMethod -Uri $updateUrl -Method Put -Headers $authHeader -Body $body
        if ($updateResponse.success) {
            Write-Host "SUCCESS: Updated $recordName -> $ip" -ForegroundColor Green
        }
        else {
            Write-Error "Failed to update record: $($updateResponse.errors[0].message)"
        }
    }
    else {
        Write-Host "IP has not changed. No update needed." -ForegroundColor Green
    }
}
catch {
    Write-Error "An error occurred: $_"
}
