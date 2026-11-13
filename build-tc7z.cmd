@echo off
REM =====================================================================
REM 用 ip7z/7zip 官方源码编译 Total Commander 的 7-Zip 插件 DLL
REM
REM tc7z*.dll 的来源:
REM   自定义 bundle Format7zTC(= 官方 Format7z + RAR/RAR5 解压 handler)
REM   与老G(TC 作者)自带的 tc7z.dll 功能一致:7z 格式打包/解压 + RAR 解压
REM   makefile 模板见仓库文件 Format7zTC-makefile
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
call :install_bundle_makefile || exit /b 1
call :bundle Format7zTC x64 7z.dll tc7z64.dll  || exit /b 1
call :bundle Format7zF  x64 7z.dll  7z-x64.dll  || exit /b 1

REM ---------- x86 (tc7z.dll + tc7z.sfx) ----------
call "%VCVARS%" x86 || exit /b 1
set "LFLAGS=/SUBSYSTEM:WINDOWS,5.01"
call :install_bundle_makefile || exit /b 1
call :bundle Format7zTC x86 7z.dll tc7z.dll    || exit /b 1
call :bundle Format7zF  x86 7z.dll  7z-x86.dll  || exit /b 1
REM SFX 自解压模块(对应老G的 tc7z.sfx,32 位可在所有 Windows 运行)
call :bundle SFXWin     x86 7z.sfx tc7z.sfx NOEXPORT || exit /b 1

REM ---------- arm64 (tc7zArm64.dll, TC 11+ 支持) ----------
if /I "%Z7_ARM64%" == "1" (
  call "%VCVARS%" amd64_arm64 || exit /b 1
  set "LFLAGS=/SUBSYSTEM:WINDOWS,6.02"
  call :install_bundle_makefile || exit /b 1
  call :bundle Format7zTC arm64 7z.dll tc7zArm64.dll || exit /b 1
  call :bundle Format7zF  arm64 7z.dll 7z-arm64.dll  || exit /b 1
)

echo.
echo [OK] all DLLs built into %OUT_BASE%
dir /b "%OUT_BASE%"
exit /b 0

REM ---------------------------------------------------------------------
REM :install_bundle_makefile
REM 把仓库里的 Format7zTC-makefile 模板安装到源码树 Bundles\Format7zTC\
REM (脚本与本模板文件位于同一目录)
:install_bundle_makefile
set "MKDIR=%SRC%\CPP\7zip\Bundles\Format7zTC"
set "FMT7Z=%SRC%\CPP\7zip\Bundles\Format7z"
if not exist "%MKDIR%" mkdir "%MKDIR%"
set "TPL=%~dp0Format7zTC-makefile"
if not exist "%TPL%" (
  echo [ERROR] makefile template not found: %TPL%
  exit /b 1
)
copy /y "%TPL%" "%MKDIR%\makefile" >nul || exit /b 1
copy /y "%FMT7Z%\StdAfx.cpp" "%MKDIR%\" >nul || exit /b 1
copy /y "%FMT7Z%\StdAfx.h"   "%MKDIR%\" >nul || exit /b 1
copy /y "%FMT7Z%\resource.rc" "%MKDIR%\" >nul || exit /b 1
exit /b 0

REM ---------------------------------------------------------------------
REM :bundle <bundle名> <平台> <makefile产物名> <输出文件名> [NOEXPORT]
REM 编译单个 bundle 并把产物复制到 OUT_BASE,校验 CreateObject 导出
REM (第5个参数为 NOEXPORT 时跳过导出校验,用于 SFX 模块等非 DLL 产物)
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
if /I "%~5" == "NOEXPORT" (
  echo [OK] %~4 built ^(no export check^)
  exit /b 0
)
dumpbin /EXPORTS "%OUT_BASE%\%~4" | findstr /C:"CreateObject" >nul
if errorlevel 1 (
  echo [ERROR] %~4: missing CreateObject export, not a valid 7-Zip codec DLL
  exit /b 1
)
echo [OK] %~4 built and export check passed
exit /b 0
