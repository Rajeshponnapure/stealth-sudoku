# Deploy Stealth Push Edge Function and set required secrets.
# Usage: Run in PowerShell from project root. Replace placeholders before running.

Set-StrictMode -Version Latest

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  Write-Error "supabase CLI is not installed or not on PATH. Install from https://supabase.com/docs/guides/cli"
  exit 1
}

$projectRef = Read-Host 'Enter Supabase project ref (or press Enter to skip)'
if ([string]::IsNullOrWhiteSpace($projectRef)) { $projectArg = '' } else { $projectArg = "--project-ref $projectRef" }

Write-Host 'Installing function dependencies...'
Push-Location supabase/functions/stealth-push
npm install
Pop-Location

Write-Host 'Set Supabase secrets (you will be prompted).'
Write-Host 'Provide SERVICE_ROLE_KEY (service_role key)'
supabase secrets set SERVICE_ROLE_KEY --project-ref $projectRef
Write-Host 'Provide SUPABASE_URL'
supabase secrets set SUPABASE_URL --project-ref $projectRef
Write-Host 'Provide FCM_SERVER_KEY (legacy server key) or set FIREBASE_SERVICE_ACCOUNT JSON as needed'
supabase secrets set FCM_SERVER_KEY --project-ref $projectRef

Write-Host 'Deploying function...'
supabase functions deploy stealth-push $projectArg

Write-Host 'Invoke a test run (this does not send FCM until push_requests exist)'
supabase functions invoke stealth-push $projectArg

Write-Host 'Done.'
