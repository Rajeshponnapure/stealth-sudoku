# Deploy Stealth Push Edge Function and set required secrets.
# Usage: Run in PowerShell from project root.

Set-StrictMode -Version Latest

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
  Write-Error "npx is not installed or not on PATH. Install Node.js first."
  exit 1
}

$projectRef = Read-Host 'Enter Supabase project ref (or press Enter to skip)'
$projectRef = $projectRef.Trim()

$firebaseJsonPath = Read-Host 'Path to downloaded Firebase service-account JSON file'
$firebaseJsonPath = $firebaseJsonPath.Trim().Trim('"').Trim("'")

if (-not (Test-Path $firebaseJsonPath)) {
  Write-Error "Firebase JSON file not found: $firebaseJsonPath"
  exit 1
}

$functionEnvPath = Join-Path $PSScriptRoot 'functions\stealth-push\.env'
if (-not (Test-Path $functionEnvPath)) {
  # Fallback to root .env if function .env is missing
  $functionEnvPath = Join-Path $PSScriptRoot '..\.env'
}

$serviceAccountJson = Get-Content $firebaseJsonPath -Raw | ConvertFrom-Json | ConvertTo-Json -Compress -Depth 100
$tempEnvPath = Join-Path $env:TEMP 'stealth-push-env.txt'

# ✅ Ensure NO BOM and NO extra whitespace
$envContent = Get-Content $functionEnvPath -Raw
$finalEnv = "$($envContent.Trim())`nFIREBASE_SERVICE_ACCOUNT=$serviceAccountJson"
[System.IO.File]::WriteAllText($tempEnvPath, $finalEnv)

Write-Host 'Installing function dependencies...'
Push-Location supabase/functions/stealth-push
npm install
Pop-Location

Write-Host 'Setting Supabase secrets from env file...'
if ($projectRef) {
    npx supabase secrets set --env-file $tempEnvPath --project-ref $projectRef
} else {
    npx supabase secrets set --env-file $tempEnvPath
}

Remove-Item $tempEnvPath -ErrorAction SilentlyContinue

Write-Host 'Deploying function...'
if ($projectRef) {
    npx supabase functions deploy stealth-push --project-ref $projectRef
} else {
    npx supabase functions deploy stealth-push
}

Write-Host 'Done.'
