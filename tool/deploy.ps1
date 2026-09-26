# Builds Rabta against production and publishes it to Cloudflare Pages.
#
#   .\tool\deploy.ps1
#
# Run from the project folder. Reads CLOUDFLARE_API_TOKEN and
# CLOUDFLARE_ACCOUNT_ID from supabase/.env.prod, and the app's own production
# settings from env.prod.json; both files are git-ignored.
#
# Direct upload rather than Cloudflare building from git: their build image has
# no Flutter, and this way what is deployed is exactly what was built and
# looked at here.

# No $ErrorActionPreference = 'Stop': in Windows PowerShell 5.1 it makes any
# line a native tool writes to stderr fatal, and flutter writes its ordinary
# notes there. Each step's exit code is checked instead.
Set-Location (Split-Path $PSScriptRoot -Parent)

foreach ($line in Get-Content 'supabase/.env.prod') {
    if ($line -match '^\s*(CLOUDFLARE_[A-Z_]+)\s*=\s*"?([^"]*)"?\s*$') {
        Set-Item "Env:$($Matches[1])" $Matches[2]
    }
}
if (-not $env:CLOUDFLARE_API_TOKEN -or -not $env:CLOUDFLARE_ACCOUNT_ID) {
    throw 'CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID are missing from supabase/.env.prod'
}

flutter build web --release --dart-define-from-file=env.prod.json
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

npx --yes wrangler pages deploy build/web --project-name=rabta --branch=main --commit-dirty=true
if ($LASTEXITCODE -ne 0) { throw 'wrangler deploy failed' }
