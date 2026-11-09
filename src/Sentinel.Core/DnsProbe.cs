using System.Buffers.Binary;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
namespace Sentinel.Core;
public static class DnsProbe {
 public static byte[] Query(string name) {
  var b=new List<byte>(RandomNumberGenerator.GetBytes(2));b.AddRange([1,0,0,1,0,0,0,0,0,0]);
  foreach(var label in DnsWire.Normalize(name).Split('.')){b.Add((byte)label.Length);b.AddRange(Encoding.ASCII.GetBytes(label));}
  b.AddRange([0,0,1,0,1]);return b.ToArray();
 }
 public static string[] ReadAddresses(byte[] b) {
  if(b.Length<12 || (b[2]&128)==0 || (b[3]&15)!=0)throw new InvalidDataException();
  int pos=12; var addresses=new List<string>();
  int U16(int p){if(p<0 || p+2>b.Length)throw new InvalidDataException();return BinaryPrimitives.ReadUInt16BigEndian(b.AsSpan(p,2));}
  void SkipName(){for(int hops=0;hops<128;hops++){
   if(pos>=b.Length)throw new InvalidDataException();int n=b[pos++];if(n==0)return;
   if((n&192)==192){if(pos>=b.Length || (((n&63)<<8)|b[pos])>=b.Length)throw new InvalidDataException();pos++;return;}
   if(n>63 || pos+n>b.Length)throw new InvalidDataException();pos+=n;
  }throw new InvalidDataException();}
  for(int i=0;i<U16(4);i++){SkipName();pos+=4;if(pos>b.Length)throw new InvalidDataException();}
  for(int i=0;i<U16(6);i++){
   SkipName();if(pos+10>b.Length)throw new InvalidDataException();int type=U16(pos),cls=U16(pos+2),len=U16(pos+8);pos+=10;
   if(pos+len>b.Length)throw new InvalidDataException();if(type==1 && cls==1 && len==4)addresses.Add(new IPAddress(b.AsSpan(pos,len)).ToString());pos+=len;
  }
  return addresses.ToArray();
 }
 public static async Task<bool> Check(IPAddress ip,int port,CancellationToken ct) {
  using var timeout=CancellationTokenSource.CreateLinkedTokenSource(ct);timeout.CancelAfter(5000);
  using var udp=new UdpClient(ip.AddressFamily);udp.Connect(ip,port);
  foreach(var name in new[]{"nudity.testcategory.com","example.com"}){
   var q=Query(name);await udp.SendAsync(q,timeout.Token);var r=(await udp.ReceiveAsync(timeout.Token)).Buffer;
   if(r.Length<12 || r[0]!=q[0] || r[1]!=q[1])return false;
   var ips=ReadAddresses(r);if(ips.Length==0)return false;
   if(name.StartsWith("nudity",StringComparison.Ordinal)){if(ips.Any(a=>a!="0.0.0.0"))return false;}
   else if(ips.Any(a=>a=="0.0.0.0"))return false;
  }return true;
 }
}
