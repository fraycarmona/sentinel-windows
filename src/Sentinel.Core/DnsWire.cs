using System.Globalization;
using System.Text;
namespace Sentinel.Core;
public static class DnsWire {
 public static string Question(byte[] b) {
  if(b.Length<17 || b.Length>4096 || (b[2]&0xF8)!=0 || b[4]!=0 || b[5]!=1) throw new InvalidDataException("DNS no válido");
  int i=12; var labels=new List<string>(); int total=0;
  while(true) {
   if(i>=b.Length) throw new InvalidDataException(); int n=b[i++]; if(n==0) break;
   if(n>63 || i+n>b.Length || (total+=n+1)>254) throw new InvalidDataException();
   for(int k=i;k<i+n;k++) if(b[k]<33 || b[k]>126) throw new InvalidDataException();
   labels.Add(Encoding.ASCII.GetString(b,i,n)); i+=n;
  }
  if(i+4>b.Length || b[i+2]!=0 || b[i+3]!=1) throw new InvalidDataException();
  return string.Join('.',labels).ToLowerInvariant();
 }
 public static byte[] Error(byte[] query,int code) {
  Question(query); int i=12; while(query[i]!=0) i+=query[i]+1; i+=5;
  var b=query[..i]; b[2]=(byte)(0x80|(query[2]&1)); b[3]=(byte)(0x80|code);
  Array.Clear(b,6,6); return b;
 }
 public static bool Matches(string host,string rule)=>host==rule || host.EndsWith("."+rule,StringComparison.Ordinal);
 public static string Normalize(string rule) {
  string s=new IdnMapping().GetAscii(rule.Trim().TrimEnd('.')).ToLowerInvariant();
  if(s.Length==0 || s.Length>253 || s.Split('.').Any(l=>l.Length==0 || l.Length>63 || l.StartsWith('-') || l.EndsWith('-') || l.Any(c=>!char.IsAsciiLetterOrDigit(c)&&c!='-'))) throw new InvalidDataException("Dominio inválido");
  return s;
 }
}
public sealed class DomainRules {
 readonly string[] denied,allowed;
 public DomainRules(IEnumerable<string> deny,IEnumerable<string> allow) { denied=deny.Select(DnsWire.Normalize).ToArray(); allowed=allow.Select(DnsWire.Normalize).ToArray(); }
 public bool Blocks(string name)=>!allowed.Any(r=>DnsWire.Matches(name,r)) && denied.Any(r=>DnsWire.Matches(name,r));
}
