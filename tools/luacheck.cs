using System;
using System.IO;
using System.Runtime.InteropServices;

// Syntax-checks Lua files with the game's own lua51.dll (LuaJIT, 32-bit).
class LuaCheck {
    [DllImport("lua51.dll", CallingConvention = CallingConvention.Cdecl)] static extern IntPtr luaL_newstate();
    [DllImport("lua51.dll", CallingConvention = CallingConvention.Cdecl)] static extern int luaL_loadfile(IntPtr L, string file);
    [DllImport("lua51.dll", CallingConvention = CallingConvention.Cdecl)] static extern IntPtr lua_tolstring(IntPtr L, int idx, IntPtr len);
    [DllImport("lua51.dll", CallingConvention = CallingConvention.Cdecl)] static extern void lua_settop(IntPtr L, int idx);
    [DllImport("kernel32.dll")] static extern bool SetDllDirectory(string path);

    static int Main(string[] args) {
        SetDllDirectory(args[0]);
        IntPtr L = luaL_newstate();
        int bad = 0;
        foreach (var f in Directory.GetFiles(args[1], "*.lua", SearchOption.AllDirectories)) {
            if (luaL_loadfile(L, f) != 0) {
                bad++;
                Console.WriteLine("ERROR " + Marshal.PtrToStringAnsi(lua_tolstring(L, -1, IntPtr.Zero)));
            }
            lua_settop(L, 0);
        }
        Console.WriteLine(bad == 0 ? "lua syntax ok" : bad + " file(s) with errors");
        return bad;
    }
}
