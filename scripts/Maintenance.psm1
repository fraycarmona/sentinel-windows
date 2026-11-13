function Enter-SentinelMaintenance {
 $path=Join-Path $env:ProgramData 'Sentinel/maintenance.lock'
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while($true){
  try{return [IO.File]::Open($path,'OpenOrCreate','ReadWrite','None')}
  catch [IO.IOException]{if($timer.Elapsed.TotalSeconds -ge 30){throw};Start-Sleep -Milliseconds 200}
 }
}
Export-ModuleMember -Function Enter-SentinelMaintenance
