[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SupabaseUrl = "https://xnqqunnnyifoduksffjq.supabase.co",

    [Parameter(Mandatory = $false)]
    [string]$SupabaseApiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhucXF1bm5ueWlmb2R1a3NmZmpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3Mjg3NDAsImV4cCI6MjEwMjMwNDc0MH0.hICo7htTHD6QC5PQTPpikyjgPPUP4N6ZZfUepv4lBl8",

    [Parameter(Mandatory = $false)]
    [string]$TableName = "ip_lookups"
)

$ErrorActionPreference = 'Stop'

Write-Host "Step 1: Looking up public IP..." -ForegroundColor Cyan
$response = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=status,message,query,city,regionName,country,countryCode,zip,lat,lon,isp,org,timezone" -Method Get
Write-Host "IP lookup status: $($response.status)" -ForegroundColor Yellow
$response | Format-List

if ($response.status -ne 'success') {
    Write-Error "IP lookup failed: $($response.message)"
    exit 1
}

$result = [PSCustomObject]@{
    PublicIP    = $response.query
    City        = $response.city
    Region      = $response.regionName
    Country     = "$($response.country) ($($response.countryCode))"
    PostalCode  = $response.zip
    Latitude    = $response.lat
    Longitude   = $response.lon
    ISP         = $response.isp
    Org         = $response.org
    TimeZone    = $response.timezone
}

Write-Host "`nStep 2: Sending to Supabase..." -ForegroundColor Cyan
$endpoint = "$($SupabaseUrl.TrimEnd('/'))/rest/v1/$TableName"
Write-Host "Endpoint: $endpoint" -ForegroundColor Yellow

$headers = @{
    "apikey"        = $SupabaseApiKey
    "Authorization" = "Bearer $SupabaseApiKey"
    "Content-Type"  = "application/json"
    "Prefer"        = "return=minimal"
}

$body = @{
    public_ip   = $result.PublicIP
    city        = $result.City
    region      = $result.Region
    country     = $result.Country
    postal_code = $result.PostalCode
    latitude    = $result.Latitude
    longitude   = $result.Longitude
    isp         = $result.ISP
    org         = $result.Org
    time_zone   = $result.TimeZone
} | ConvertTo-Json

Write-Host "Body being sent:" -ForegroundColor Yellow
Write-Host $body

try {
    $insertResponse = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -Body $body
    Write-Host "`nSUCCESS - Status code: $($insertResponse.StatusCode)" -ForegroundColor Green
}
catch {
    Write-Host "`nFAILED" -ForegroundColor Red
    Write-Host "Status code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    $errorBody = $_.ErrorDetails.Message
    Write-Host "Response body: $errorBody" -ForegroundColor Red
}
