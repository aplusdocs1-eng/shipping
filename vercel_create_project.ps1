$token=$env:VERCEL_TOKEN
if (-not $token) { Write-Host 'ERROR: set $env:VERCEL_TOKEN before running this script'; exit 1 }
$payload=@'
{"name":"shipping","gitRepository":{"type":"github","org":"aplusdocs1-eng","repo":"shipping","deployProtection":false},"buildCommand":"flutter build web --release","outputDirectory":"build/web"}
'@
Set-Content -Path vercel_payload.json -Value $payload -Encoding utf8
Write-Host 'GET TEAMS...'
curl.exe -s -H "Authorization: Bearer $token" https://api.vercel.com/v1/teams -o vercel_teams.json
if (Test-Path vercel_teams.json) {
  $teams = Get-Content vercel_teams.json | ConvertFrom-Json
  $teamId = ($teams | Select-Object -First 1).id
  Write-Host 'FOUND_TEAM_ID:' $teamId
  $body = Get-Content vercel_payload.json -Raw
  $hdr=@{ Authorization="Bearer $token"; 'Content-Type'='application/json' }
  try {
    Invoke-RestMethod -Method Post -Uri ("https://api.vercel.com/v9/projects?teamId=" + $teamId) -Headers $hdr -Body $body -ErrorAction Stop | ConvertTo-Json -Depth 10 > vercel_project_response.json
    Write-Host 'CREATED PROJECT'
    Get-Content vercel_project_response.json -TotalCount 200
  } catch {
    $_ | Out-String | Write-Host
    if (Test-Path vercel_project_response.json) { Get-Content vercel_project_response.json -TotalCount 200 }
  }
} else { Write-Host 'NO TEAMS FILE' }
