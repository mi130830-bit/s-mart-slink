$zoneName = "namecheap.work"
$recordName = "possb.namecheap.work"
$email = "Mi130830@gmail.com"
$apiKey = "b3228559bdada32277eaf41ca962abd6ecc4b"

# 1. Get Zone ID
$zoneUri = "https://api.cloudflare.com/client/v4/zones?name=$zoneName"
$headers = @{
    "X-Auth-Email" = $email
    "X-Auth-Key"   = $apiKey
    "Content-Type" = "application/json"
}
$zoneResponse = Invoke-RestMethod -Uri $zoneUri -Method Get -Headers $headers
$zoneId = $zoneResponse.result[0].id

# 2. Get Record ID
$recordUri = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?name=$recordName"
$recordResponse = Invoke-RestMethod -Uri $recordUri -Method Get -Headers $headers
$recordId = $recordResponse.result[0].id

if ($recordId) {
    # 3. Delete Record
    $deleteUri = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId"
    Invoke-RestMethod -Uri $deleteUri -Method Delete -Headers $headers
    Write-Host "Deleted existing record for $recordName"
}
else {
    Write-Host "No existing record found for $recordName"
}
