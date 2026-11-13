using Sentinel.Core;
using System.Text;
using System.Text.Json;
int passed=0;
void Test(string name,Action run){run();Console.WriteLine("PASS "+name);passed++;}
void Check(bool b){if(!b)throw new Exception("Assertion failed");}
void Reject(Action action){try{action();}catch(Exception e) when(e is InvalidDataException or ArgumentException or JsonException){return;}throw new Exception("Expected rejection");}
Test("No desbloqueo anticipado",()=>Check(!LockState.Request(DateTimeOffset.UtcNow).Advance(86399).Ready));
Test("Desbloqueo tras 86400 segundos",()=>Check(LockState.Request(DateTimeOffset.UtcNow).Advance(86400).Ready));
Test("Reloj civil no interviene",()=>Check(LockState.Request(DateTimeOffset.MinValue).RemainingSeconds==LockState.Request(DateTimeOffset.MaxValue).RemainingSeconds));
Test("Rechaza tiempo negativo y NaN",()=>{Reject(()=>LockState.Request(DateTimeOffset.UtcNow).Advance(-1));Reject(()=>LockState.Request(DateTimeOffset.UtcNow).Advance(double.NaN));});
Test("Estado persistente y cancelación",()=>{var p=Path.Combine(Path.GetTempPath(),Guid.NewGuid()+".json");try{var s=new LockStore(p);s.Save(LockState.Request(DateTimeOffset.UtcNow).Advance(123));Check(new LockStore(p).Read()!.RemainingSeconds==86277);s.Save(null);Check(s.Read()==null);}finally{File.Delete(p);}});
Test("Corrupción no habilita retirada",()=>{var p=Path.GetTempFileName();try{File.WriteAllText(p,"garbage");Reject(()=>new LockStore(p).Read());}finally{File.Delete(p);}});
Test("Versiones desconocidas rechazadas",()=>Reject(()=>new LockState(2,DateTimeOffset.UtcNow,0).Validate()));
Test("Límite de dominio y exclusión",()=>{var r=new DomainRules(["example.test"],["safe.example.test"]);Check(r.Blocks("a.example.test"));Check(!r.Blocks("notexample.test"));Check(!r.Blocks("safe.example.test"));});
Test("Normalización IDN",()=>Check(DnsWire.Normalize("BÜCHER.test.")=="xn--bcher-kva.test"));
Test("Entradas inválidas",()=>{Reject(()=>DnsWire.Normalize("a..test"));Reject(()=>DnsWire.Normalize("https://test"));});
byte[] Query(){var b=new List<byte>{1,2,1,0,0,1,0,0,0,0,0,0};foreach(var s in new[]{"blocked","test"}){b.Add((byte)s.Length);b.AddRange(Encoding.ASCII.GetBytes(s));}b.AddRange([0,0,1,0,1]);return b.ToArray();}
Test("DNS parse y NXDOMAIN",()=>{var q=Query();Check(DnsWire.Question(q)=="blocked.test");var b=DnsWire.Error(q,3);Check(b[0]==1 && b[1]==2 && (b[3]&15)==3 && (b[2]&128)!=0);});
Test("Truncado y compresión maliciosa",()=>{Reject(()=>DnsWire.Question(new byte[5]));var q=Query();q[12]=192;Reject(()=>DnsWire.Question(q));});
Test("Fuzz parser 10000 entradas",()=>{var r=new Random(42);for(int i=0;i<10000;i++){byte[] b=new byte[r.Next(0,600)];r.NextBytes(b);try{DnsWire.Question(b);}catch(InvalidDataException){}}});
Test("Reglas Twitter y subdominios",()=>{var r=new DomainRules(["x.com","twitter.com","twimg.com","t.co"],[]);Check(r.Blocks("x.com") && r.Blocks("api.twitter.com") && r.Blocks("pbs.twimg.com") && r.Blocks("t.co"));Check(!r.Blocks("notx.com"));});
Test("Consulta de diagnóstico",()=>Check(DnsWire.Question(DnsProbe.Query("example.com"))=="example.com"));
Test("Respuesta A del diagnóstico y truncamiento",()=>{
 var q=DnsProbe.Query("example.com");q[2]=0x81;q[3]=0x80;q[7]=1;
 var b=q.Concat(new byte[]{192,12,0,1,0,1,0,0,0,30,0,4,0,0,0,0}).ToArray();
 Check(DnsProbe.ReadAddresses(b).SequenceEqual(new[]{"0.0.0.0"}));Reject(()=>DnsProbe.ReadAddresses(b[..^1]));
});
Test("Fuzz diagnóstico 10000 entradas",()=>{var r=new Random(43);for(int i=0;i<10000;i++){var b=new byte[r.Next(0,600)];r.NextBytes(b);try{DnsProbe.ReadAddresses(b);}catch(InvalidDataException){}}});
Test("SafeSearch solo nombres exactos y no cuentas",()=>{
 Check(SafeSearch.Target("www.google.es")=="forcesafesearch.google.com");
 Check(SafeSearch.Target("accounts.google.com")==null && SafeSearch.Target("mail.google.com")==null && SafeSearch.Target("notgoogle.com")==null);
 Check(SafeSearch.Target("www.bing.com")=="strict.bing.com" && SafeSearch.Target("www.youtube.com")=="restrict.youtube.com");
});
Test("Respuesta SafeSearch filtra familia y no entrega SVCB",()=>{
 var q=DnsProbe.Query("www.google.com");
 var ips=new[]{System.Net.IPAddress.Parse("216.239.38.120"),System.Net.IPAddress.Parse("2001:4860::1")};
 Check(DnsProbe.ReadAddresses(SafeSearch.Answer(q,ips)).SequenceEqual(new[]{"216.239.38.120"}));
 q[^3]=28;Check(DnsProbe.ReadAddresses(SafeSearch.Answer(q,ips),true).SequenceEqual(new[]{"2001:4860::1"}));
 q[^3]=65;Check(SafeSearch.Answer(q,ips)[7]==0);
});
Test("Pipe ajeno no concede autoridad aunque el servicio real exista",()=>{
 var name="Sentinel.Test."+Guid.NewGuid();
 using var server=new System.IO.Pipes.NamedPipeServerStream(name,System.IO.Pipes.PipeDirection.InOut,1,System.IO.Pipes.PipeTransmissionMode.Byte,System.IO.Pipes.PipeOptions.Asynchronous);
 var connect=server.WaitForConnectionAsync();
 using var client=new System.IO.Pipes.NamedPipeClientStream(".",name,System.IO.Pipes.PipeDirection.InOut);
 client.Connect(2000);connect.GetAwaiter().GetResult();
 bool denied=false;try{PipeIdentity.AssertService(client);}catch(IOException){denied=true;}
 Check(denied);
});
Console.WriteLine($"{passed} pruebas superadas");
