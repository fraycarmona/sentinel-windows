function Test-SentinelFilteredResolver {
 param([string]$Server='127.0.0.1')
 try{
  $allowed=@(Resolve-DnsName example.com -Server $Server -Type A -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction Stop | Where-Object Type -eq A)
  $blocked=@(Resolve-DnsName nudity.testcategory.com -Server $Server -Type A -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction Stop | Where-Object Type -eq A)
  return ($allowed.Count -gt 0 -and @($allowed | Where-Object IPAddress -eq '0.0.0.0').Count -eq 0 -and $blocked.Count -gt 0 -and @($blocked | Where-Object IPAddress -ne '0.0.0.0').Count -eq 0)
 }catch{return $false}
}
Export-ModuleMember -Function Test-SentinelFilteredResolver
