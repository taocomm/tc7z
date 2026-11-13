@echo off
REM =====================================================================
REM 用 ip7z/7zip 官方源码编译 Total Commander 的 7-Zip 插件 DLL
REM
REM 方法与 mcmilk/7-Zip-zstd 完全一致:
REM   Bundles\Format7z  -> 7za.dll  -> 改名 tc7z.dll / tc7z64.dll / tc7zArm64.dll
REM   Bundles\Format7zF -> 7z.dll   -> 完整版解码 DLL(可选,用于替换 7-Zip 本体)
REM
REM 用法: build-tc7z.cmd [源码目录] [输出目录]
REM 环境: 已装 Visual Studio 2022(含 vswhere)的 Windows 环境
REM =====================================================================
setlocal enabledelayedexpansion

if "%~1" == "" (set "SRC=%~dp07zip-src") else set "SRC=%~f1"
if "%~2" == "" (set "OUT_BASE=%~dp0out") else set "OUT_BASE=%~f2"
if not exist "%OUT_BASE%" mkdir "%OUT_BASE%"

if "%Z7_ARM64%" == "" set "Z7_ARM64=1"

for /f "usebackq tokens=*" %%i in (`vswhere -latest -property installationPath`) do set "VSPATH=%%i"
if not defined VSPATH (
  echo [ERROR] vswhere not found / Visual Studio missing
  exit /b 1
)
set "VCVARS=%VSPATH%\VC\Auxiliary\Build\vcvarsall.bat"
if not exist "%VCVARS%" (
  echo [ERROR] vcvarsall.bat not found: %VCVARS%
  exit /b 1
)

REM ---------- x64 (tc7z64.dll) ----------
call "%VCVARS%" x64 || exit /b 1
set "LFLAGS=/SUBSYSTEM:WINDOWS,5.02"
call :bundle Format7z  x64 7za.dll tc7z64.dll  || exit /b 1
call :bundle Format7zF x64 7z.dll  7z-x64.dll  || exit /b 1

REM ---------- x86 (tc7z.dll) ----------
call "%VCVARS%" x86 || exit /b 1
set "LFLAGS=/SUBSYSTEM:WINDOWS,5.01"
call :bundle Format7z  x86 7za.dll tc7z.dll    || exit /b 1
call :bundle Format7zF x86 7z.dll  7z-x86.dll  || exit /b 1

REM ---------- arm64 (tc7zArm64.dll, TC 11+ 支持) ----------
if /I "%Z7_ARM64%" == "1" (
  call "%VCVARS%" amd64_arm64 || exit /b 1
  set "LFLAGS=/SUBSYSTEM:WINDOWS,6.02"
  call :bundle Format7z  arm64 7za.dll tc7zArm64.dll || exit /b 1
  call :bundle Format7zF arm64 7z.dll  7z-arm64.dll  || exit /b 1
)

echo.
echo [OK] all DLLs built into %OUT_BASE%
dir /b "%OUT_BASE%"
exit /b 0

REM ---------------------------------------------------------------------
REM :bundle <bundle名> <平台> <makefile产物名> <输出文件名>
REM 编译单个 bundle 并把产物复制到 OUT_BASE,校验 CreateObject 导出
:bundle
echo.
echo ====== build %~1 (%~2)  -^>  %~4 ======
cd /d "%SRC%\CPP\7zip\Bundles\%~1" || exit /b 1
nmake -nologo PLATFORM=%~2 || exit /b 1
if not exist "%~2\%~3" (
  echo [ERROR] expected output not found: %~1\%~2\%~3
  exit /b 1
)
copy /y "%~2\%~3" "%OUT_BASE%\%~4" >nul || exit /b 1
dumpbin /EXPORTS "%OUT_BASE%\%~4" | findstr /C:"CreateObject" >nul
if errorlevel 1 (
  echo [ERROR] %~4: missing CreateObject export, not a valid 7-Zip codec DLL
  exit /b 1
)
echo [OK] %~4 built and export check passed
exit /b 0
