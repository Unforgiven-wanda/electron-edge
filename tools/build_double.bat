@echo off
set SELF=%~dp0
if "%1" equ "" (
    echo Usage: build_double.bat {node_version}
    echo e.g. build_double.bat 0.10.28
    exit /b -1
)

mkdir "%SELF%\build\nuget" > nul 2>&1

if not exist "%SELF%\build\download.exe" (
	csc /out:"%SELF%\build\download.exe" "%SELF%\download.cs"
)

if not exist "%SELF%\build\unzip.exe" (
	csc /out:"%SELF%\build\unzip.exe" /r:System.IO.Compression.FileSystem.dll "%SELF%\unzip.cs"
)

if not exist "%SELF%\build\repl.exe" (
	csc /out:"%SELF%\build\repl.exe" "%SELF%\repl.cs"
)

if not exist "%SELF%\build\%1.zip" (
	"%SELF%\build\download.exe" https://github.com/joyent/node/archive/v%1.zip "%SELF%\build\%1.zip"
)

if not exist "%SELF%\build\node-%1" (
	"%SELF%\build\unzip.exe" "%SELF%\build\%1.zip" "%SELF%\build"
)

call :build_node %1 x86
if %ERRORLEVEL% neq 0 exit /b -1
call :build_node %1 x64
if %ERRORLEVEL% neq 0 exit /b -1

if not exist "%SELF%\build\node-%1-x86\node.exe" (
	"%SELF%\build\download.exe" http://nodejs.org/dist/v%1/node.exe "%SELF%\build\node-%1-x86\node.exe"
)

if not exist "%SELF%\build\node-%1-x64\node.exe" (
	"%SELF%\build\download.exe" http://nodejs.org/dist/v%1/x64/node.exe "%SELF%\build\node-%1-x64\node.exe"
)

call :build_edge %1 x86
if %ERRORLEVEL% neq 0 exit /b -1
call :build_edge %1 x64
if %ERRORLEVEL% neq 0 exit /b -1

csc /out:"%SELF%\build\nuget\Edge.Js.dll" /target:library /res:"%SELF%\build\node-%1-x86\node.dll",node86.dll /res:"%SELF%\build\node-%1-x64\node.dll",node64.dll "%SELF%\..\src\double\dotnet\Edge.Js.cs"
if %ERRORLEVEL% neq 0 exit /b -1

copy /y "%SELF%\..\lib\edge.js" "%SELF%\build\nuget"

exit /b 0

:build_edge

rem takes 2 parameters: 1 - node version, 2 - x86 or x64

rmdir /s /q "%SELF%\build\nuget\%2" > nul 2>&1

set NODEEXE=%SELF%\build\node-%1-%2\node.exe
set GYP=%APPDATA%\npm\node_modules\node-gyp\bin\node-gyp.js

pushd "%SELF%\.."

"%NODEEXE%" "%GYP%" configure --msvs_version=2013
"%SELF%\build\repl.exe" ./build/edge.vcxproj "%USERPROFILE%\.node-gyp\%1\$(Configuration)\node.lib" "%SELF%\build\node-%1-%2\node.lib"
"%NODEEXE%" "%GYP%" build
mkdir "%SELF%\build\nuget\%2" > nul 2>&1
copy /y build\release\edge.node "%SELF%\build\nuget\%2"

popd

exit /b 0

:build_node

rem takes 2 parameters: 1 - node version, 2 - x86 or x64

if exist "%SELF%\build\node-%1-%2" exit /b 0

pushd "%SELF%\build\node-%1"

..\repl.exe node.gyp "'executable'" "'shared_library'"
if %ERRORLEVEL% neq 0 (
    echo Cannot update node.gyp 
    popd
    exit /b -1
)

call vcbuild.bat build release %2
mkdir "%SELF%\build\node-%1-%2"
copy /y .\Release\node.* "%SELF%\build\node-%1-%2"
echo Finished building Node shared library %1

popd
exit /b 0