using System.Net;
namespace Sentinel.Core;
public static class SafeSearch {
 // Exact search hosts only: never rewrite mail, login, APIs or arbitrary subdomains.
 public static string? Target(string host) => host.ToLowerInvariant().TrimEnd('.') switch {
  "google.com" or "www.google.com" or "google.es" or "www.google.es" => "forcesafesearch.google.com",
  "bing.com" or "www.bing.com" => "strict.bing.com",
  "youtube.com" or "www.youtube.com" or "m.youtube.com" or "youtubei.googleapis.com" or "youtube.googleapis.com" or "www.youtube-nocookie.com" => "restrict.youtube.com",
  _ => null
 };
 public static byte[] Answer(byte[] query, IEnumerable<IPAddress> addresses) {
  var answer=DnsWire.Error(query,0); int type=(answer[^4]<<8)|answer[^3];
  var records=new List<byte>(); int count=0;
  if(type is 1 or 28)foreach(var ip in addresses.Distinct().Take(16)){
   var bytes=ip.GetAddressBytes(); if((type==1 && bytes.Length!=4)||(type==28 && bytes.Length!=16))continue;
   records.AddRange(new byte[]{192,12,0,(byte)type,0,1,0,0,0,60,0,(byte)bytes.Length});records.AddRange(bytes);count++;
  }
  // No HTTPS/SVCB hints: those must not supply an unfiltered alternative endpoint.
  answer[7]=(byte)count;return answer.Concat(records).ToArray();
 }
}
