using System.IO;
using System.IO.Pipes;
using System.Net;
using System.Net.NetworkInformation;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Diagnostics;
using Sentinel.Core;
namespace Sentinel.UI;
public partial class MainWindow:Window {
 readonly System.Windows.Threading.DispatcherTimer timer=new(){Interval=TimeSpan.FromSeconds(5)};
 bool busy,healthy; DateTimeOffset healthTime=DateTimeOffset.MinValue;
 readonly bool demo=Environment.GetCommandLineArgs().Contains("--demo");
 public MainWindow(){InitializeComponent();Loaded+=async(_,_)=>await Update(Environment.GetCommandLineArgs().Contains("--uninstall")?(byte)1:(byte)0);timer.Tick+=async(_,_)=>await Update(0);timer.Start();Closed+=(_,_)=>timer.Stop();}
 async void Request(object s,RoutedEventArgs e)=>await Update(1);
 async void Cancel(object s,RoutedEventArgs e)=>await Update(2);
 async void Refresh(object s,RoutedEventArgs e){healthTime=DateTimeOffset.MinValue;await Update(0);}
 async void FinalizeRemoval(object s,RoutedEventArgs e){
  string script=Path.Combine(AppContext.BaseDirectory,"scripts","remove-lab.ps1");
  if(!File.Exists(script))script=Path.GetFullPath(Path.Combine(AppContext.BaseDirectory,"..","scripts","remove-lab.ps1"));
  if(!File.Exists(script)){MessageBox.Show("No se encuentra el desinstalador. Consulte la documentación de recuperación.");return;}
  try{
   using var process=Process.Start(new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe")){
    UseShellExecute=true,Verb="runas",WindowStyle=ProcessWindowStyle.Hidden,Arguments=$"-NoProfile -File \"{script}\" -AcceptLabChanges"});
   if(process is not null)await process.WaitForExitAsync();await Update(0);
   if(process?.ExitCode!=0)MessageBox.Show("No se completó la retirada. Puede haber una espera pendiente o un conflicto de restauración. Consulte la recuperación documentada.","SENTINEL");
  }catch(System.ComponentModel.Win32Exception){MessageBox.Show("Windows no concedió la elevación. El servicio continúa con su estado anterior.");}
 }
 async void Activate(object s,RoutedEventArgs e){
  string script=Path.Combine(AppContext.BaseDirectory,"scripts","activate.ps1");
  if(!File.Exists(script))script=Path.GetFullPath(Path.Combine(AppContext.BaseDirectory,"..","scripts","activate.ps1"));
  if(!File.Exists(script)){MessageBox.Show("Este ejecutable muestra el estado. Para instalar, utiliza el paquete completo SENTINEL y su carpeta scripts.","Paquete de instalación necesario");return;}
  ActivateButton.IsEnabled=false;
  try{
   var info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe")){
    UseShellExecute=true,Verb="runas",WindowStyle=ProcessWindowStyle.Hidden,Arguments=$"-NoProfile -File \"{script}\""};
   using var process=Process.Start(info);if(process is not null)await process.WaitForExitAsync();
   healthTime=DateTimeOffset.MinValue;await Update(0);
   if(process?.ExitCode!=0)MessageBox.Show("No se completó la activación. Consulte el diagnóstico; no se declara protección activa.","SENTINEL");
  }catch(System.ComponentModel.Win32Exception){MessageBox.Show("Windows no concedió la elevación. No se ha activado la protección.","SENTINEL");}
  finally{ActivateButton.IsEnabled=true;}
 }
 static bool AdaptersUseLoopback(){
  var nics=NetworkInterface.GetAllNetworkInterfaces().Where(n=>n.OperationalStatus==OperationalStatus.Up && n.NetworkInterfaceType is NetworkInterfaceType.Ethernet or NetworkInterfaceType.Wireless80211).ToArray();
  return nics.Length>0 && nics.All(n=>{var ips=n.GetIPProperties().DnsAddresses;return ips.Count>0 && ips.All(IPAddress.IsLoopback);});
 }
 void Paint(string status,string message,string color){Status.Text=status;Summary.Text=message;StatusCard.Background=(Brush)new BrushConverter().ConvertFromString(color)!;}
 async Task Update(byte command){if(busy)return;busy=true;
  try{
   using var timeout=new CancellationTokenSource(2500);using var pipe=new NamedPipeClientStream(".",demo?"Sentinel.Demo":"Sentinel.Control",PipeDirection.InOut,PipeOptions.Asynchronous);
   await pipe.ConnectAsync(timeout.Token);if(!demo)PipeIdentity.AssertService(pipe);await pipe.WriteAsync(new[]{command},timeout.Token);using var reader=new StreamReader(pipe);string json=await reader.ReadToEndAsync(timeout.Token);using var doc=JsonDocument.Parse(json);var d=doc.RootElement;
   Motor.Text="Motor: EN EJECUCIÓN";
   var policy=BrowserPolicies.Check();
   Strict.Text=$"Navegadores: {policy.Matching}/{policy.Total} ajustes comprobados. Reinicie los navegadores tras instalar.\nInicio automático: {(BrowserPolicies.AutomaticStart()?"configurado":"NO configurado")}. Cobertura de VPN/proxy: parcial.";
   FinalizeButton.IsEnabled=d.GetProperty("Ready").GetBoolean();
   if(DateTimeOffset.UtcNow-healthTime>TimeSpan.FromSeconds(30)){
    try{using var check=new CancellationTokenSource(12000);healthy=await DnsProbe.Check(IPAddress.Loopback,demo?1053:53,check.Token) && await DnsProbe.Check(IPAddress.IPv6Loopback,demo?1053:53,check.Token);}
    catch(Exception ex) when(ex is IOException or System.Net.Sockets.SocketException or OperationCanceledException){healthy=false;}
    healthTime=DateTimeOffset.UtcNow;
   }
   bool routed=!demo && AdaptersUseLoopback();
   bool active=routed && healthy;
   if(active)Paint("FILTRADO DNS ACTIVO","El motor responde y los adaptadores comprobados usan el filtro.","#124B40");
   else if(demo)Paint("MODO DE PRUEBA","El motor funciona en modo local. NO protege la navegación del equipo.","#5C431D");
   else Paint("PROTECCIÓN DEGRADADA","El motor funciona, pero el filtrado del equipo no está verificado.","#5C431D");
   Dns.Text=$"DNS: {(healthy?"prueba del filtro correcta":"prueba del filtro no superada")} · {(routed?"adaptadores configurados":"adaptadores no verificados")}";
   bool x=d.TryGetProperty("TwitterBlocked",out var xb) && xb.GetBoolean();
   Twitter.Text="Twitter / X: "+(x?(active?"BLOQUEADO POR DNS":"reglas cargadas; protección no activa"):"reglas no verificadas");
   var remaining=d.GetProperty("Remaining");Countdown.Text=remaining.ValueKind==JsonValueKind.Null?"No hay solicitud pendiente.":d.GetProperty("Ready").GetBoolean()?"Espera completada. Puede ejecutar la retirada documentada.":$"Tiempo de servicio restante: {TimeSpan.FromSeconds(remaining.GetDouble()):c}";
   Details.Text=$"Bloqueos locales: {d.GetProperty("Blocked")} · Errores DNS: {d.GetProperty("Failures")}\n{d.GetProperty("Error").GetString()}";
  }catch(Exception e) when(e is IOException or UnauthorizedAccessException or OperationCanceledException or JsonException or NetworkInformationException){
   FinalizeButton.IsEnabled=false;healthy=false;Strict.Text="Controles anti-evasión: SIN VERIFICAR";Paint("PROTECCIÓN INACTIVA","No hay un motor accesible. Esta ventana por sí sola NO bloquea páginas.","#5B2931");Motor.Text="Motor: DETENIDO O NO ACCESIBLE";Dns.Text="DNS: SIN VERIFICAR";Twitter.Text="Twitter / X: NO ACTIVO";Countdown.Text="Sin conexión con el servicio.";Details.Text="Puedes dejar abierta esta ventana para ver el estado. Se actualiza cada 5 segundos.";
  }finally{Updated.Text="Última comprobación: "+DateTimeOffset.Now.ToString("HH:mm:ss");busy=false;}
 }
}
