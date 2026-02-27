# Test d'envoi Boîte à idées via HTTP (même appel que l'app Windows)
$url = "https://us-central1-offibox-prod.cloudfunctions.net/sendIdeasEmailHttp"
$body = @{
    data = @{
        message = "Test depuis PowerShell"
        email   = "test@example.com"
    }
} | ConvertTo-Json -Depth 3

Write-Host "URL: $url"
Write-Host "Body: $body"
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri $url -Method POST -Body $body -ContentType "application/json" -UseBasicParsing
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)"
} catch {
    Write-Host "Erreur: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        Write-Host "Body: $($reader.ReadToEnd())"
    }
}
