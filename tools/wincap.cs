using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

// Captures one process's main window (only that window) to a PNG: wincap.exe <process name> <out.png>
class WinCap {
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    struct RECT { public int L, T, R, B; }
    struct POINT { public int X, Y; }

    static int Main(string[] a) {
        SetProcessDPIAware();
        var ps = Process.GetProcessesByName(a[0]);
        if (ps.Length == 0 || ps[0].MainWindowHandle == IntPtr.Zero) { Console.WriteLine("no window"); return 1; }
        IntPtr h = ps[0].MainWindowHandle;
        RECT r; GetClientRect(h, out r);
        int w = r.R - r.L, hh = r.B - r.T;
        var bmp = new Bitmap(w, hh);
        using (var g = Graphics.FromImage(bmp)) {
            var p = new POINT(); ClientToScreen(h, ref p);
            if (a.Length > 2 && a[2] == "print") {
                IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 3); g.ReleaseHdc(dc);
            } else g.CopyFromScreen(p.X, p.Y, 0, 0, new Size(w, hh));
        }
        bmp.Save(a[1], ImageFormat.Png);
        Console.WriteLine("saved " + w + "x" + hh);
        return 0;
    }
}
