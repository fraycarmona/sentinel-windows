using Microsoft.Win32;
namespace Sentinel.Core;
public static class BrowserPolicies {
 public static (int Matching,int Total) Check(){
  var values=new List<(string Path,string Name,object Value)>();
  foreach(var browser in new[]{"Microsoft\\Edge","Google\\Chrome"}){
   string path="SOFTWARE\\Policies\\"+browser;
   values.AddRange(new[]{(path,"DnsOverHttpsMode",(object)"off"),(path,"ProxySettings",(object)"{\"ProxyMode\":\"direct\"}"),
    (path,browser.StartsWith("Microsoft",StringComparison.Ordinal)?"InPrivateModeAvailability":"IncognitoModeAvailability",(object)1),
    (path,"BrowserGuestModeEnabled",(object)0),(path,"ForceGoogleSafeSearch",(object)1),(path,"ForceYouTubeRestrict",(object)2)});
  }
  values.Add(("SOFTWARE\\Policies\\Microsoft\\Edge","ForceBingSafeSearch",2));
  const string ff="SOFTWARE\\Policies\\Mozilla\\Firefox";
  values.AddRange(new[]{(ff+"\\DNSOverHTTPS","Enabled",(object)0),(ff+"\\DNSOverHTTPS","Locked",(object)1),
   (ff+"\\Proxy","Mode",(object)"none"),(ff+"\\Proxy","Locked",(object)1),(ff,"DisablePrivateBrowsing",(object)1)});
  int matched=0;using var hive=RegistryKey.OpenBaseKey(RegistryHive.LocalMachine,RegistryView.Registry64);
  foreach(var v in values){using var key=hive.OpenSubKey(v.Path);if(Equals(key?.GetValue(v.Name),v.Value))matched++;}
  return (matched,values.Count);
 }
 public static bool AutomaticStart(){
  using var hive=RegistryKey.OpenBaseKey(RegistryHive.LocalMachine,RegistryView.Registry64);
  using var key=hive.OpenSubKey("SYSTEM\\CurrentControlSet\\Services\\Sentinel");return Equals(key?.GetValue("Start"),2);
 }
}
