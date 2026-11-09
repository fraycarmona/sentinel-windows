using Sentinel.Core;
using System.Diagnostics;
using System.IO.Pipes;
using System.Net;
using System.Net.Sockets;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text.Json;
namespace Sentinel.Service;
public sealed class Engine {
 readonly string dir; readonly int port; readonly bool demo;
 readonly LockStore store; readonly object gate=new(); LockState? state; string? stateError;
 readonly SemaphoreSlim slots=new(64); readonly HttpClient http=new(new SocketsHttpHandler {
  UseProxy=false,
  ConnectCallback=async (context,ct)=>{
   // Bootstrap by fixed provider IP, retaining HTTPS SNI and normal certificate validation.
   Exception? last=null;
   foreach(var ip in new[]{"1.1.1.3","1.0.0.3","2606:4700:4700::1113","2606:4700:4700::1003"}) {
    var socket=new Socket(SocketType.Stream,ProtocolType.Tcp);
    try{using var attempt=CancellationTokenSource.CreateLinkedTokenSource(ct);attempt.CancelAfter(1000);await socket.ConnectAsync(IPAddress.Parse(ip),443,attempt.Token);return new NetworkStream(socket,true);}
    catch(Exception e) when(e is SocketException or OperationCanceledException){socket.Dispose();last=e;}
   }
   throw new IOException("Proveedor DNS no disponible",last);
  }
 }){Timeout=TimeSpan.FromSeconds(6)};
 DomainRules rules=new([],[]); long blocked,failures; DateTimeOffset? lastDns;
 public Engine(string dir,int port,bool demo){this.dir=dir;this.port=port;this.demo=demo;store=new(Path.Combine(dir,"lock.json"));}
 public async Task Run(CancellationToken ct) {
  try {state=store.Read();} catch(Exception e) when(e is IOException or JsonException){stateError="Estado de espera dañado: recuperación necesaria";}
  var r=JsonSerializer.Deserialize<RulesConfig>(File.ReadAllText(Path.Combine(dir,"rules.json"))) ?? throw new InvalidDataException();
  rules=new(r.Deny,r.Allow);
  var tasks=new[]{Udp(IPAddress.Loopback,ct),Udp(IPAddress.IPv6Loopback,ct),Tcp(IPAddress.Loopback,ct),Tcp(IPAddress.IPv6Loopback,ct),Clock(ct),Pipe(ct)};
  var first=await Task.WhenAny(tasks); await first; ct.ThrowIfCancellationRequested(); throw new IOException("Componente detenido");
 }
 async Task Clock(CancellationToken ct) {
  long last=Stopwatch.GetTimestamp();
  while(!ct.IsCancellationRequested){await Task.Delay(1000,ct); long now=Stopwatch.GetTimestamp();
   // Cap credit after suspend; do not trust wall-clock jumps or time asleep.
   double elapsed=Math.Min(2,Stopwatch.GetElapsedTime(last,now).TotalSeconds);last=now;
   lock(gate){if(state is not null && stateError is null){state=state.Advance(elapsed);try{store.Save(state);}catch(IOException){stateError="No se puede persistir la espera";}}}
  }
 }
 async Task<byte[]> Resolve(byte[] q,CancellationToken ct) {
  string host=DnsWire.Question(q);
  if(rules.Blocks(host)){Interlocked.Increment(ref blocked);return DnsWire.Error(q,3);}
  try {
   using var req=new HttpRequestMessage(HttpMethod.Post,"https://family.cloudflare-dns.com/dns-query");
   req.Content=new ByteArrayContent(q);req.Content.Headers.ContentType=new("application/dns-message");
   using var response=await http.SendAsync(req,HttpCompletionOption.ResponseHeadersRead,ct);response.EnsureSuccessStatusCode();
   await using var stream=await response.Content.ReadAsStreamAsync(ct);
   using var data=new MemoryStream();var buffer=new byte[4096];int n;
   while((n=await stream.ReadAsync(buffer,ct))!=0){if(data.Length+n>65535)throw new InvalidDataException();data.Write(buffer,0,n);}
   var b=data.ToArray();if(b.Length<12 || b[0]!=q[0] || b[1]!=q[1] || (b[2]&128)==0)throw new InvalidDataException();
   lock(gate)lastDns=DateTimeOffset.UtcNow;return b;
  }catch(Exception e) when(e is HttpRequestException or IOException or TaskCanceledException){Interlocked.Increment(ref failures);return DnsWire.Error(q,2);}
 }
 async Task Udp(IPAddress ip,CancellationToken ct){
  using var udp=new UdpClient(new IPEndPoint(ip,port));
  while(!ct.IsCancellationRequested){var packet=await udp.ReceiveAsync(ct);if(!slots.Wait(0))continue;
   _=Handle(); async Task Handle(){try{var b=await Resolve(packet.Buffer,ct); if(b.Length>512)b=Truncate(packet.Buffer);await udp.SendAsync(b,packet.RemoteEndPoint,ct);}catch(Exception e) when(e is IOException or SocketException or OperationCanceledException or ObjectDisposedException){}finally{slots.Release();}}
  }
 }
 static byte[] Truncate(byte[] q){var b=DnsWire.Error(q,0);b[2]|=2;return b;}
 async Task Tcp(IPAddress ip,CancellationToken ct){
  var listener=new TcpListener(ip,port);listener.Start(64);
  try{while(!ct.IsCancellationRequested){var client=await listener.AcceptTcpClientAsync(ct);if(!slots.Wait(0)){client.Dispose();continue;}_=Handle();
   async Task Handle(){using(client)using(var timeout=CancellationTokenSource.CreateLinkedTokenSource(ct)){timeout.CancelAfter(TimeSpan.FromSeconds(10));
    try{var s=client.GetStream();byte[] size=new byte[2];await s.ReadExactlyAsync(size,timeout.Token);int n=(size[0]<<8)|size[1];if(n<17 || n>4096)return;
     byte[] q=new byte[n];await s.ReadExactlyAsync(q,timeout.Token);var b=await Resolve(q,timeout.Token);await s.WriteAsync(new byte[]{(byte)(b.Length>>8),(byte)b.Length},timeout.Token);await s.WriteAsync(b,timeout.Token);
    }catch(Exception e) when(e is IOException or SocketException or OperationCanceledException){}finally{slots.Release();}}}
  }}finally{listener.Stop();}
 }
 async Task Pipe(CancellationToken ct){
  string owner=File.ReadAllText(Path.Combine(dir,"owner.txt")).Trim();
  var security=new PipeSecurity();security.AddAccessRule(new(new SecurityIdentifier(owner),PipeAccessRights.ReadWrite,AccessControlType.Allow));
  security.AddAccessRule(new(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),PipeAccessRights.FullControl,AccessControlType.Allow));
  security.AddAccessRule(new(new SecurityIdentifier(WellKnownSidType.LocalServiceSid,null),PipeAccessRights.FullControl,AccessControlType.Allow));
  security.AddAccessRule(new(new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null),PipeAccessRights.ReadWrite,AccessControlType.Allow));
  security.AddAccessRule(new(new SecurityIdentifier(WellKnownSidType.NetworkSid,null),PipeAccessRights.FullControl,AccessControlType.Deny));
  while(!ct.IsCancellationRequested){
   using var pipe=NamedPipeServerStreamAcl.Create(demo?"Sentinel.Demo":"Sentinel.Control",PipeDirection.InOut,1,PipeTransmissionMode.Byte,PipeOptions.Asynchronous,4096,4096,security);
   await pipe.WaitForConnectionAsync(ct);using var timeout=CancellationTokenSource.CreateLinkedTokenSource(ct);timeout.CancelAfter(3000);
   try{var command=new byte[1];await pipe.ReadExactlyAsync(command,timeout.Token);string json;
    lock(gate){
     if(command[0]==1 && stateError is null && state is null){state=LockState.Request(DateTimeOffset.UtcNow);store.Save(state);}
     if(command[0]==2 && stateError is null){store.Save(null);state=null;}
     json=JsonSerializer.Serialize(new {Protection="DEGRADADA", Service="EN EJECUCIÓN", Demo=demo, TwitterBlocked=rules.Blocks("x.com") && rules.Blocks("twitter.com") && rules.Blocks("twimg.com") && rules.Blocks("t.co"), Dns=lastDns, Blocked=Interlocked.Read(ref blocked), Failures=Interlocked.Read(ref failures), Remaining=state?.RemainingSeconds, Ready=stateError is null && state?.Ready==true, Error=stateError, Scope=demo?"Prueba local :1053; no protege el equipo":"Cobertura DNS; no garantiza bloqueo de VPN, proxies o DNS propio del navegador"});
    }
    await pipe.WriteAsync(System.Text.Encoding.UTF8.GetBytes(json),timeout.Token);
   }catch(Exception e) when(e is IOException or OperationCanceledException){ }
  }
 }
 record RulesConfig(string[] Deny,string[] Allow);
}
