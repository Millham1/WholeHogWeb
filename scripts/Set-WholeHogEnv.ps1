# Set-WholeHogEnv.ps1
[CmdletBinding()]
param(
  [string]$EnvPath = ".env.local",
  [string]$SupabaseUrl = "https://wiolulxxfyetvdpnfusq.supabase.co",
  [string]$SupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc"
)

Write-Host "Writing environment to $EnvPath ..." -ForegroundColor Cyan

$lines = @(
  "NEXT_PUBLIC_SUPABASE_URL=$SupabaseUrl"
  "NEXT_PUBLIC_SUPABASE_ANON_KEY=$SupabaseAnonKey"
)

$body = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
Set-Content -Path $EnvPath -Value $body -Encoding UTF8

Write-Host "✅ .env.local written." -ForegroundColor Green
