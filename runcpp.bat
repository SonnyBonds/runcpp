@if (1 == 0) @end /*
@cscript.exe /E:jscript /nologo "%~f0" %*
@goto :eof
*/

function run(command, echo)
{
    //WScript.Echo(command);
    var wshell = WScript.CreateObject("WScript.Shell");
    var proc = wshell.Exec("cmd /c \"" + command + "\"");
    while(!proc.StdOut.AtEndOfStream || !proc.StdErr.AtEndOfStream)
    {
        var out = proc.StdOut.ReadAll();
        var err = proc.StdErr.ReadAll();
        if(echo)
        {
            WScript.StdOut.Write(out);
            WScript.StdErr.Write(err);
        }
    }
    return proc.ExitCode;
}

function getOutput(command)
{
    var wshell = WScript.CreateObject("WScript.Shell");
    var proc = wshell.Exec("cmd /c \"" + command + "\"");
    var out = "";
    while(!proc.StdOut.AtEndOfStream || !proc.StdErr.AtEndOfStream)
    {
        out += proc.StdOut.ReadAll();
        proc.StdErr.ReadAll();
    }
    if(proc.ExitCode == 0)
    {
        return out;
    }
}

function versionSort(a, b)
{
    a = a.split(".")
    b = b.split(".")
    for(var i = 0; i < a.length || i < b.length; i++)
    {
        var va = a[i] || 0;
        var vb = b[i] || 0;
        if (va != vb)
        {
            return va - vb;
        }
    }
    return 0
}

function getLatestSubFolder(path)
{
    if(fs.FolderExists(path))
    {
        var folder = fs.GetFolder(path);
        var versions = [];
        for (var folderIt = new Enumerator(folder.SubFolders); !folderIt.atEnd(); folderIt.moveNext())
        {
            versions.push(folderIt.item().Name);
        }
        if(versions.length > 0)
        {
            versions.sort(versionSort);
            return path + "\\" + versions[versions.length-1]
        }
    }
}

function findVCPaths(pattern)
{
    var result = getOutput("\"c:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe\" -latest -find " + pattern);
    result = result.replace(/\r/g, "").split("\n");
    
    // WScript doesn't seem to support Array.filter
    var filteredResult = [];
    for(var i in result)
    {
        if(result[i].length > 0)
        {
            filteredResult.push(result[i]);
        }
    }

    return filteredResult;
}

function findMSVC()
{
    // Being a bit specific here. If we were picky we wouldn't be here anyway.
    var clPath = findVCPaths("**\\Hostx64\\x64\\cl.exe");
    if(clPath.length == 0)
    {
        return;
    }

    var flags = "";

    var includePaths = findVCPaths("**\\MSVC\\**\\include");
    if(includePaths.length == 0)
    {
        return;
    }

    var libPaths = findVCPaths("**\\MSVC\\**\\lib\\x64");
    if(libPaths.length == 0)
    {
        return;
    }

    var kitFolder = getLatestSubFolder("C:\\Program Files (x86)\\Windows Kits");
    if(!kitFolder)
    {
        return;
    }

    var kitIncludeFolder = getLatestSubFolder(kitFolder + "\\Include");
    if(!kitIncludeFolder)
    {
        return;
    }
    includePaths.push(kitIncludeFolder + "\\shared");
    includePaths.push(kitIncludeFolder + "\\ucrt");
    includePaths.push(kitIncludeFolder + "\\um");
    includePaths.push(kitIncludeFolder + "\\winrt");

    var kitLibFolder = getLatestSubFolder(kitFolder + "\\Lib");
    if(!kitLibFolder)
    {
        return;
    }
    libPaths.push(kitLibFolder + "\\ucrt\\x64");
    libPaths.push(kitLibFolder + "\\um\\x64");

    for(var i in includePaths)
    {
        flags += " /I\"" + includePaths[i] + "\"";
    }

    flags += " /link";

    for(var i in libPaths)
    {
        flags += " /libpath:\"" + libPaths[i] + "\"";
    }

    return ["\"" + clPath + "\"", flags];
}

function buildMSVC()
{
    var clPath;
    var ok = false;
    
    var flags = ""
    if(!ok)
    {
        clPath = "cl";
        // If cl is on the path let's just assume we've got a full environment and go
        ok = run(clPath) == 0;
    }

    if(!ok)
    {
        // If cl is not on the path, we do some digging...
        var msvc = findMSVC();
        if(msvc && msvc.length == 2 && msvc[0].length > 0)
        {
            clPath = msvc[0]
            flags = msvc[1]
            ok = run(clPath + " /?") == 0;
        }
    }

    if(!ok)
    {
        return false;
    }

    result = run(clPath + " /nologo /std:c++17 /EHsc /Ox /MD " + input + " /Fe:" + output + flags, true);
    if(result != 0)
    {
        WScript.Quit(result);
    }

    return true;
}

function buildClang()
{
    var clangPath;
    var ok = false;
    
    if(!ok)
    {
        clangPath = "clang++";
        ok = run(clangPath + " --version") == 0;
    }

    if(!ok)
    {
        clangPath = "\"C:\\Program Files\\LLVM\\bin\\clang++.exe\"";
        ok = run(clangPath + " --version") == 0;
    }

    if(!ok)
    {
        return false;
    }

    result = run(clangPath + " -std=c++17 -O3 " + input + " -o " + output, true);
    if(result != 0)
    {
        WScript.Quit(result);
    }

    return true;
}

function build()
{
    if(buildClang()) return true;
    if(buildMSVC()) return true;
    WScript.Echo("Unable to find a working compiler.");
    WScript.Quit(1);
}


if(WScript.Arguments.Count() < 1)
{
    WScript.Echo("Usage: runcpp input.cpp [arguments to compiled program]")
    WScript.Quit(1);
}

var input = WScript.Arguments(0);
var output = input + ".exe";

var fs = WScript.CreateObject("Scripting.FileSystemObject");
if(!fs.FileExists(input))
{
    WScript.Echo("Input file '" + input + "' does not exist.")
    WScript.Quit(1);
}

if(fs.FileExists(output))
{
    var inputFile = fs.GetFile(input);
    var outputFile = fs.GetFile(output);
    if(new Date(inputFile.DateLastModified).getTime() > new Date(outputFile.DateLastModified).getTime())
    {
        build();
    }
}
else
{
    build();
}

var args = ""
for(var i = 1; i < WScript.Arguments.Count(); i++)
{
    args += " \"" + WScript.Arguments(i) + "\""
}

WScript.Quit(run(output + args, true));