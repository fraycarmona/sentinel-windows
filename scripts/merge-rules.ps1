#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$path=Join-Path $env:ProgramData 'Sentinel/rules.json'
$rules=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
# Additive migration: preserve all previous blocks and exceptions; no weakening UI is exposed.
$required=@('blocked.test','x.com','twitter.com','t.co','twimg.com','stripchat.com','dns.google','cloudflare-dns.com','mozilla.cloudflare-dns.com','dns.quad9.net','doh.opendns.com')
$rules.Deny=@(@($rules.Deny)+$required | Sort-Object -Unique)
if(!(Test-Path ($path+'.pre05'))){Copy-Item -LiteralPath $path -Destination ($path+'.pre05')}
$temp=$path+'.tmp';[IO.File]::WriteAllText($temp,($rules | ConvertTo-Json -Depth 5))
[IO.File]::Replace($temp,$path,[NullString]::Value)
