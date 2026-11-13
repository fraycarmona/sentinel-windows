Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:encoding=[Text.Encoding]::GetEncoding(28591) # reversible byte mapping; preserve foreign bytes
function New-SentinelHostsBlock {
 param([string[]]$Domains)
 $lines=@('', '# SENTINEL BEGIN v1')
 foreach($d in @($Domains | Sort-Object -Unique)){
  if($d -notmatch '^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$' -or $d.Length -gt 253 -or $d.Contains('..')){throw 'Dominio de hosts no válido.'}
  foreach($hostName in @($d,('www.'+$d))){$lines+=('0.0.0.0 '+$hostName);$lines+=(':: '+$hostName)}
 }
 $lines+= '# SENTINEL END v1'
 return ($lines -join "`r`n")+"`r`n"
}
function Write-SentinelHostsAtomic {
 param([string]$Path,[string]$Text)
 $temp=$Path+'.sentinel-'+[guid]::NewGuid().ToString('N')+'.tmp'
 try{
  $stream=[IO.File]::Open($temp,'CreateNew','Write','None')
  try{$bytes=$script:encoding.GetBytes($Text);$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
  [IO.File]::Replace($temp,$Path,[NullString]::Value)
 }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp}}
}
function Add-SentinelHosts {
 param([string]$Path,[string]$Journal,[string[]]$Domains)
 $current=$script:encoding.GetString([IO.File]::ReadAllBytes($Path))
 if(Test-Path -LiteralPath $Journal){
  $j=Get-Content -LiteralPath $Journal -Raw | ConvertFrom-Json
  if($j.Path -cne $Path -or !$current.Contains([string]$j.Block) -or $j.Block -cne (New-SentinelHostsBlock $Domains)){throw 'Diario/hosts en conflicto o reglas nuevas: revisar actualización residual.'}
  return
 }
 if($current.Contains('# SENTINEL ')){throw 'Existe una sección SENTINEL sin diario.'}
 $block=New-SentinelHostsBlock $Domains
 $record=[pscustomobject]@{Version=1;Path=$Path;Block=$block;Before=[Convert]::ToBase64String($script:encoding.GetBytes($current))}
 $json=$record | ConvertTo-Json
 $stream=[IO.File]::Open($Journal,'CreateNew','Write','None')
 try{$bytes=[Text.Encoding]::UTF8.GetBytes($json);$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
 Write-SentinelHostsAtomic $Path ($current+$block)
 if($script:encoding.GetString([IO.File]::ReadAllBytes($Path)) -cne ($current+$block)){throw 'No coincide la lectura de hosts.'}
}
function Remove-SentinelHosts {
 param([string]$Path,[string]$Journal)
 if(!(Test-Path -LiteralPath $Journal)){return}
 $j=Get-Content -LiteralPath $Journal -Raw | ConvertFrom-Json
 if($j.Version -ne 1 -or $j.Path -cne $Path -or !$j.Block.StartsWith("`r`n# SENTINEL BEGIN v1`r`n") -or !$j.Block.EndsWith("# SENTINEL END v1`r`n")){throw 'Diario de hosts inválido.'}
 $current=$script:encoding.GetString([IO.File]::ReadAllBytes($Path));$index=$current.IndexOf([string]$j.Block,[StringComparison]::Ordinal)
 if($index -ge 0){
  if($current.LastIndexOf([string]$j.Block,[StringComparison]::Ordinal) -ne $index){throw 'Sección de hosts duplicada.'}
  Write-SentinelHostsAtomic $Path ($current.Remove($index,$j.Block.Length))
 }elseif($current.Contains('# SENTINEL ')){throw 'Sección hosts modificada; se conserva el diario.'}
 Remove-Item -LiteralPath $Journal
}
Export-ModuleMember -Function New-SentinelHostsBlock,Add-SentinelHosts,Remove-SentinelHosts
