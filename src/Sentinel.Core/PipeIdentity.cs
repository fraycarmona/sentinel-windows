using System;
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
#if NET
#pragma warning disable 8625
#endif

namespace Sentinel.Core {
// Also compiled by Windows PowerShell 5.1. Keep this file compatible with C# 5.
public static class PipeIdentity {
 [DllImport("kernel32.dll", SetLastError=true)]
 static extern bool GetNamedPipeServerProcessId(SafePipeHandle pipe, out uint pid);
 [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
 static extern IntPtr OpenSCManager(string machine, string database, uint access);
 [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
 static extern IntPtr OpenService(IntPtr scm, string name, uint access);
 [DllImport("advapi32.dll", SetLastError=true)]
 static extern bool QueryServiceStatusEx(IntPtr service, int level, out ServiceStatus status, int size, out int needed);
 [DllImport("advapi32.dll")] static extern bool CloseServiceHandle(IntPtr handle);
 [StructLayout(LayoutKind.Sequential)]
 struct ServiceStatus { public uint Type, State, Controls, Win32Exit, ServiceExit, CheckPoint, WaitHint, Pid, Flags; }
 public static void AssertService(NamedPipeClientStream pipe) {
  uint serverPid;
  if(!GetNamedPipeServerProcessId(pipe.SafePipeHandle,out serverPid) || serverPid==0) throw new IOException("No se puede autenticar el canal de SENTINEL.");
  IntPtr scm=OpenSCManager(null,null,1), service=IntPtr.Zero;
  try {
   if(scm==IntPtr.Zero) throw new IOException("SCM no accesible.");
   service=OpenService(scm,"Sentinel",4);
   ServiceStatus status; int needed;
   if(service==IntPtr.Zero || !QueryServiceStatusEx(service,0,out status,Marshal.SizeOf(typeof(ServiceStatus)),out needed) || status.State!=4 || status.Pid==0 || status.Pid!=serverPid)
    throw new IOException("El canal no pertenece al servicio SENTINEL en ejecución.");
  } finally { if(service!=IntPtr.Zero)CloseServiceHandle(service);if(scm!=IntPtr.Zero)CloseServiceHandle(scm); }
 }
}
}
