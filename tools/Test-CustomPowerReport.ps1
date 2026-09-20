param(
    [string]$RuntimePath = (Join-Path $PSScriptRoot '..\runtime'),
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\src'),
    [string]$TestPath = (Join-Path $PSScriptRoot '..\tests\custom_power_report.lua')
)
$ErrorActionPreference = 'Stop'
$RuntimePath = (Resolve-Path -LiteralPath $RuntimePath).Path
$SourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
$testPath = (Resolve-Path -LiteralPath $TestPath).Path

# Run the functional checks inside the shipped LuaJIT DLL, without installing a second interpreter.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PoBTestLua {
    [DllImport("kernel32", CharSet = CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
    [DllImport("kernel32", CharSet = CharSet.Unicode)] public static extern IntPtr LoadLibrary(string path);
    [DllImport("lua51", CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr luaL_newstate();
    [DllImport("lua51", CallingConvention = CallingConvention.Cdecl)] public static extern void luaL_openlibs(IntPtr state);
    [DllImport("lua51", CallingConvention = CallingConvention.Cdecl)] public static extern int luaL_loadstring(IntPtr state, string code);
    [DllImport("lua51", CallingConvention = CallingConvention.Cdecl)] public static extern int lua_pcall(IntPtr state, int args, int results, int error);
    [DllImport("lua51", CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr lua_tolstring(IntPtr state, int index, IntPtr length);
    [DllImport("lua51", CallingConvention = CallingConvention.Cdecl)] public static extern void lua_close(IntPtr state);
}
'@
$previousDirectory = [Environment]::CurrentDirectory
$state = [IntPtr]::Zero
try {
    [Environment]::CurrentDirectory = $SourcePath
    [PoBTestLua]::SetDllDirectory($RuntimePath) | Out-Null
    if ([PoBTestLua]::LoadLibrary((Join-Path $RuntimePath 'lua51.dll')) -eq [IntPtr]::Zero) { throw 'Cannot load upstream LuaJIT runtime.' }
    $state = [PoBTestLua]::luaL_newstate()
    [PoBTestLua]::luaL_openlibs($state)
    $runtimeLuaPath = $RuntimePath.Replace('\', '/')
    $scriptLuaPath = $testPath.Replace('\', '/')
    $code = "package.path = [==[$runtimeLuaPath/lua/?.lua;$runtimeLuaPath/lua/?/init.lua;]==] .. package.path; package.cpath = [==[$runtimeLuaPath/?.dll;]==] .. package.cpath; dofile([==[$scriptLuaPath]==])"
    $result = [PoBTestLua]::luaL_loadstring($state, $code)
    if ($result -eq 0) { $result = [PoBTestLua]::lua_pcall($state, 0, 0, 0) }
    if ($result -ne 0) { throw [Runtime.InteropServices.Marshal]::PtrToStringAnsi([PoBTestLua]::lua_tolstring($state, -1, [IntPtr]::Zero)) }
    Write-Output "Headless functional checks passed: $([IO.Path]::GetFileName($testPath))"
} finally {
    if ($state -ne [IntPtr]::Zero) { [PoBTestLua]::lua_close($state) }
    [PoBTestLua]::SetDllDirectory($null) | Out-Null
    [Environment]::CurrentDirectory = $previousDirectory
}
