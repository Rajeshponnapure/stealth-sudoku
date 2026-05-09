# Apply Supabase Database Migrations
# This script applies the SQL migrations to fix the database schema

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Applying Stealth Sudoku DB Migrations" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$projectRef = "owyjeacntzcnugfpayeb"

Write-Host ""
Write-Host "Project: $projectRef" -ForegroundColor Yellow
Write-Host ""

# Check if supabase CLI is installed
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Error "npx is not installed. Please install Node.js first."
    exit 1
}

Write-Host "Step 1: Linking to Supabase project..." -ForegroundColor Green
npx supabase link --project-ref $projectRef

Write-Host ""
Write-Host "Step 2: Pushing database migrations..." -ForegroundColor Green
npx supabase db push

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Migration complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If the above failed, you can manually run the SQL in the Supabase Dashboard:"
Write-Host "1. Go to https://supabase.com/dashboard/project/$projectRef"
Write-Host "2. Open SQL Editor"
Write-Host "3. Copy and paste the contents of:"
Write-Host "   - supabase/migrations/20260509_fix_profiles_email.sql"
Write-Host "   - supabase/migrations/20260509_emergency_sync_fix.sql"
Write-Host ""
