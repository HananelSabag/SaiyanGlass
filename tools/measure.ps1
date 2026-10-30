# Measures the whole-desktop cost of SaiyanGlass (or of stock Windows, for a
# baseline): CPU, memory, handles and GPU 3D time of the shell processes, dwm
# and our own processes, while running a scripted scenario.
#
#   .\tools\measure.ps1 -Label baseline -Scenario idle
#   .\tools\measure.ps1 -Label glass    -Scenario all
#
# Scenarios: idle, start, windows, wallpaper, all. "wallpaper" advances the
# slideshow (the same as "Next desktop background"); it never changes settings.
param(
    [Parameter(Mandatory)][string]$Label,
    [ValidateSet('idle', 'start', 'windows', 'wallpaper', 'all')][string]$Scenario = 'idle',
    [int]$IdleSeconds = 60,
    [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot) 'bench\results')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Desk {
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    public static void Key(byte vk) { keybd_event(vk, 0, 0, UIntPtr.Zero); keybd_event(vk, 0, 2, UIntPtr.Zero); }

    [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDesktopWallpaper {
        void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [return: MarshalAs(UnmanagedType.LPWStr)] string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
        [return: MarshalAs(UnmanagedType.LPWStr)] string GetMonitorDevicePathAt(uint monitorIndex);
        uint GetMonitorDevicePathCount();
        void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID, out long rect1, out long rect2);
        void SetBackgroundColor(uint color);
        uint GetBackgroundColor();
        void SetPosition(int position);
        int GetPosition();
        void SetSlideshow(IntPtr items);
        IntPtr GetSlideshow();
        void SetSlideshowOptions(int options, uint slideshowTick);
        void GetSlideshowOptions(out int options, out uint slideshowTick);
        void AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorID, int direction);
        int GetStatus();
        bool Enable();
    }
    [ComImport, Guid("C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD")] public class DesktopWallpaperClass { }
    public static void NextWallpaper() {
        var w = (IDesktopWallpaper)new DesktopWallpaperClass();
        w.AdvanceSlideshow(null, 0);
        Marshal.ReleaseComObject(w);
    }
}
'@

$cores = [Environment]::ProcessorCount
$names = 'explorer', 'dwm', 'StartMenuExperienceHost', 'SearchHost', 'SaiyanGlass', 'SaiyanGlassSettings'

function Snapshot {
    $o = @{}
    foreach ($n in $names) {
        $p = Get-Process $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) {
            $o[$n] = [ordered]@{ pid = $p.Id; cpuSec = $p.TotalProcessorTime.TotalSeconds; privateMB = [math]::Round($p.PrivateMemorySize64 / 1MB, 1)
                wsMB = [math]::Round($p.WorkingSet64 / 1MB, 1); handles = $p.HandleCount; threads = $p.Threads.Count }
        }
    }
    $o
}

# Sums GPU running time (in ms) on 3D engines per process from the GPU Engine
# "Running Time" counter, which is cumulative and so is sampled once at start
# and once at the end.
function GpuTimes($pids) {
    $res = @{}
    $samples = (Get-Counter '\GPU Engine(*engtype_3D)\Running Time' -ErrorAction SilentlyContinue).CounterSamples
    foreach ($s in $samples) {
        if ($s.InstanceName -match '^pid_(\d+)_') {
            $id = [int]$Matches[1]
            if ($pids -contains $id) { $res[$id] = ($res[$id] + $s.RawValue) }
        }
    }
    $res
}

function Run-Scenario($name, [scriptblock]$body) {
    Write-Host "== $name"
    $before = Snapshot
    $pids = @($before.Values | ForEach-Object { $_.pid })
    $g0 = GpuTimes $pids
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $peaks = @{}
    $job = $body
    & $job
    $elapsed = $sw.Elapsed.TotalSeconds
    $after = Snapshot
    $g1 = GpuTimes $pids
    $rows = foreach ($n in $names) {
        if (-not $before[$n] -or -not $after[$n] -or $before[$n].pid -ne $after[$n].pid) { continue }
        $b = $before[$n]; $a = $after[$n]
        $gpuMs = (($g1[$a.pid] - $g0[$a.pid]) / 10000)
        [ordered]@{ process = $n; cpuPctOfMachine = [math]::Round(100 * ($a.cpuSec - $b.cpuSec) / $elapsed / $cores, 3)
            cpuMsPerSec = [math]::Round(1000 * ($a.cpuSec - $b.cpuSec) / $elapsed, 2)
            gpu3dMsPerSec = [math]::Round($gpuMs / $elapsed, 2)
            privateMB = $a.privateMB; privateDeltaMB = [math]::Round($a.privateMB - $b.privateMB, 1)
            wsMB = $a.wsMB; handles = $a.handles; handleDelta = $a.handles - $b.handles; threads = $a.threads }
    }
    [ordered]@{ scenario = $name; seconds = [math]::Round($elapsed, 1); processes = @($rows) }
}

$results = @()
$doAll = $Scenario -eq 'all'

if ($doAll -or $Scenario -eq 'idle') {
    $results += Run-Scenario 'idle' { Start-Sleep -Seconds $IdleSeconds }
}
if ($doAll -or $Scenario -eq 'start') {
    $results += Run-Scenario 'start-open-close-x10' {
        for ($i = 0; $i -lt 10; $i++) { [Desk]::Key(0x5B); Start-Sleep -Milliseconds 1200; [Desk]::Key(0x1B); Start-Sleep -Milliseconds 800 }
    }
}
if ($doAll -or $Scenario -eq 'windows') {
    # Our own test window, so no application of the user's is touched.
    Add-Type -AssemblyName System.Windows.Forms
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'SaiyanGlass measurement window'; $form.StartPosition = 'Manual'; $form.SetBounds(200, 300, 900, 600)
    $form.Show(); [System.Windows.Forms.Application]::DoEvents()
    $pump = { param($ms) $t = [Diagnostics.Stopwatch]::StartNew(); while ($t.ElapsedMilliseconds -lt $ms) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 } }
    $results += Run-Scenario 'maximize-restore-x10' {
        for ($i = 0; $i -lt 10; $i++) { $form.WindowState = 'Maximized'; & $pump 700; $form.WindowState = 'Normal'; & $pump 700 }
    }
    $results += Run-Scenario 'window-move-10s' {
        $t = [Diagnostics.Stopwatch]::StartNew(); $k = 0
        while ($t.Elapsed.TotalSeconds -lt 10) { $form.Left = 200 + [int](600 * [math]::Abs([math]::Sin($k / 30))); [System.Windows.Forms.Application]::DoEvents(); $k++; Start-Sleep -Milliseconds 16 }
    }
    $form.Close(); $form.Dispose()
}
if ($doAll -or $Scenario -eq 'wallpaper') {
    $results += Run-Scenario 'wallpaper-advance-x3' {
        for ($i = 0; $i -lt 3; $i++) { [Desk]::NextWallpaper(); Start-Sleep -Seconds 6 }
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$file = Join-Path $OutDir "$Label-$Scenario-$stamp.json"
[ordered]@{ label = $Label; when = (Get-Date).ToString('s'); build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
    cores = $cores; results = $results } | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $file
foreach ($r in $results) {
    Write-Host ("-- {0} ({1}s)" -f $r.scenario, $r.seconds)
    $r.processes | ForEach-Object { [pscustomobject]$_ } | Format-Table process, cpuMsPerSec, cpuPctOfMachine, gpu3dMsPerSec, privateMB, privateDeltaMB, handles, handleDelta -AutoSize | Out-String | Write-Host
}
"Saved $file"