using System.ServiceProcess;
namespace Sentinel.Service;
static class Program {
 static async Task Main(string[] args) {
  if(args.Contains("--console")) {
   string dir=args.SkipWhile(a=>a!="--data").Skip(1).FirstOrDefault() ?? throw new ArgumentException("--data requerido");
   using var stop=new CancellationTokenSource(); Console.CancelKeyPress+=(_,e)=>{e.Cancel=true;stop.Cancel();};
   await new Engine(dir,1053,true).Run(stop.Token);
  } else ServiceBase.Run(new WindowsService());
 }
}
sealed class WindowsService:ServiceBase {
 readonly CancellationTokenSource stop=new(); Task? task; Engine? engine;
 public WindowsService(){ServiceName="Sentinel"; CanStop=true;CanShutdown=true;}
 protected override void OnStart(string[] args){
  engine=new Engine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"Sentinel"),53,false);
  task=engine.Run(stop.Token);
  _=task.ContinueWith(t=>{if(t.IsFaulted){
   try{File.WriteAllText(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"Sentinel","runtime","service-error.txt"),DateTimeOffset.UtcNow+"\n"+t.Exception);}catch(Exception e) when(e is IOException or UnauthorizedAccessException){}
   Environment.Exit(1);
  }},TaskScheduler.Default);
 }
 // This is voluntary service-control friction, not a boundary against an administrator.
 static bool MaintenanceInProgress(){
  try{using var lease=File.Open(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"Sentinel","maintenance.lock"),FileMode.Open,FileAccess.Read,FileShare.ReadWrite);return false;}
  catch(IOException e){return (e.HResult&0xffff) is 32 or 33;}
  catch(UnauthorizedAccessException){return false;}
 }
 protected override void OnStop(){
  if(engine?.RemovalReady!=true && !MaintenanceInProgress())throw new InvalidOperationException("SENTINEL: solicite retirada y complete 24 horas; recuperación administrativa documentada.");
  StopCore();
 }
 protected override void OnShutdown()=>StopCore();
 void StopCore(){stop.Cancel();try{task?.Wait(TimeSpan.FromSeconds(8));}catch(AggregateException e) when(e.InnerExceptions.All(x=>x is OperationCanceledException)){}}
}
