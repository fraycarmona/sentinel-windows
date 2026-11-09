using System.Text.Json;
namespace Sentinel.Core;
// Only elapsed monotonic time while the service is running is credited.
// Offline time is deliberately not trusted; emergency recovery remains available.
public sealed record LockState(int Version, DateTimeOffset RequestedUtc, double RemainingSeconds) {
 public static LockState Request(DateTimeOffset utc) => new(1, utc, 86400);
 public bool Ready => RemainingSeconds == 0;
 public LockState Advance(double seconds) {
  if (!double.IsFinite(seconds) || seconds < 0) throw new ArgumentOutOfRangeException(nameof(seconds));
  return this with { RemainingSeconds = Math.Max(0, RemainingSeconds-seconds) };
 }
 public void Validate() {
  if (Version != 1 || !double.IsFinite(RemainingSeconds) || RemainingSeconds < 0 || RemainingSeconds > 86400)
   throw new InvalidDataException("Estado de espera inválido; utilice recuperación administrativa.");
 }
}
public static class AtomicFile {
 public static void Write(string path, string text) {
  Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
  string tmp=path+".tmp";
  using(var fs=new FileStream(tmp,FileMode.Create,FileAccess.Write,FileShare.None,4096,FileOptions.WriteThrough)) {
   using var w=new StreamWriter(fs,leaveOpen:true); w.Write(text); w.Flush(); fs.Flush(true);
  }
  File.Move(tmp,path,true);
 }
}
public sealed class LockStore(string path) {
 public LockState? Read() {
  if (!File.Exists(path)) throw new InvalidDataException("Falta el estado de instalación.");
  var state=JsonSerializer.Deserialize<LockState?>(File.ReadAllText(path)); state?.Validate(); return state;
 }
 public void Save(LockState? state) { state?.Validate(); AtomicFile.Write(path,JsonSerializer.Serialize(state)); }
}
