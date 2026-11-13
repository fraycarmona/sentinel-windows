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
 readonly CancellationTokenSource stop=new(); Task? task;
 public WindowsService(){ServiceName="Sentinel"; CanStop=true;}
 protected override void OnStart(string[] args){
  task=new Engine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"Sentinel"),53,false).Run(stop.Token);
  _=task.ContinueWith(t=>{if(t.IsFaulted){
   try{File.WriteAllText(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"Sentinel","service-error.txt"),DateTimeOffset.UtcNow+"\n"+t.Exception);}catch(Exception e) when(e is IOException or UnauthorizedAccessException){}
   Environment.Exit(1);
  }},TaskScheduler.Default);
 }
 protected override void OnStop(){stop.Cancel();try{task?.Wait(TimeSpan.FromSeconds(8));}catch(AggregateException e) when(e.InnerExceptions.All(x=>x is OperationCanceledException)){}}
}
