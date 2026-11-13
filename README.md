# tc7z-autobuild — 官方 7-Zip 新版自动编译 Total Commander 插件 DLL

当 [ip7z/7zip](https://github.com/ip7z/7zip) 出官方新版、而 TC 作者 Ghisler 还没更新
`tc7z.dll` 时,本仓库的 GitHub Action 会自动用官方源码编译一套 DLL 供 Total Commander
替换使用。

## 原理(逆向自 mcmilk/7-Zip-zstd)

`mcmilk/7-Zip-zstd` 每个版本发布的 `TotalCmd.7z`(内含 `tc7z.dll` / `tc7z64.dll` /
`tc7zArm64.dll`)是怎么来的?查看其 `.github/workflows/do-release.cmd` 可确认:

```
call :build Bundles\Format7z  7za.dll     ← CPP\build-it.cmd
copy %BIN%\7za.dll %WD%\totalcmd\tc7z.dll      ← do-release.cmd
copy %BIN%\7za.dll %WD%\totalcmd\tc7z64.dll
copy %BIN%\7za.dll %WD%\totalcmd\tc7zArm64.dll
7z a TotalCmd.7z ...                          ← 打包发布
```

结论:**TC 的 7-Zip 插件 DLL 就是 7-Zip 源码里 `CPP/7zip/Bundles/Format7z` 编译出的
`7za.dll` 直接改名**,该 bundle 仅含 7z 格式、使用 `Archive2.def` 导出标准 7-Zip 插件
接口(`CreateObject`、`GetNumberOfFormats` 等)。

进一步对老G随 TC 11.58.1 发布的 `tc7z*.dll` 做 PE 解析后发现:他的版本比 Format7z
多一个 **RAR/RAR5 解压 handler**(二进制含 `Rar!` 签名字符串,其余格式均无),即
Ghisler 编译的是「Format7z + RAR 解压」的定制变体(TC 还自带 unrar.dll,但 tc7z
内部同样能解 RAR)。因此本仓库用自定义 bundle **Format7zTC**(Format7z + RAR handler,
makefile 模板见 `Format7zTC-makefile`)来编译,替换后功能与老G版本完全对齐。
ip7z/7zip 官方仓库的构建系统与 mcmilk 分支完全一致(nmake + MSVC,`PLATFORM=x86/x64/arm64`),
只是 Format7z makefile 少了 zstd 等扩展 codec 的目标——正是我们需要的纯官方版本。

编译命令(在 VS 开发者环境中,Format7zTC makefile 由 build-tc7z.cmd 注入源码树):

```
cd CPP\7zip\Bundles\Format7zTC
nmake PLATFORM=x64      → x64\7z.dll → tc7z64.dll
nmake PLATFORM=x86      → x86\7z.dll → tc7z.dll
nmake PLATFORM=arm64    → arm64\7z.dll → tc7zArm64.dll
```

## 使用方法

1. 在 GitHub **新建一个仓库**(如 `tc7z-autobuild`),把本目录的 3 个文件原样放入:

   ```
   .github/workflows/build-tc7z.yml   # Actions 工作流
   build-tc7z.cmd                     # 编译脚本(MSVC nmake)
   README.md
   ```

2. 手动触发一次验证:Actions → *Build 7-Zip DLLs for Total Commander* → **Run workflow**,
   可留空版本号自动取最新,或勾选 *只编译打包不创建 Release* 先测试。

3. 之后每天北京时间凌晨 02:30 自动检查 ip7z/7zip:
   有新版本 tag → 自动编译 → 在本仓库创建 Release `7z-<版本号>`,
   产物包含 `TotalCmd.7z`、各架构 DLL 和 SHA256SUMS.txt;版本没变则跳过(以 release tag 是否存在为准)。

4. 更新 TC:下载 `TotalCmd.7z`,关闭 TC,把 `tc7z.dll`(32位)、`tc7z64.dll`(64位)、
   `tc7zArm64.dll`(ARM64)复制到 Total Commander 安装目录覆盖同名文件,重启 TC。

## 注意事项

- **官方格式限定**:本方案编译的是纯官方源码,只含标准 7z 格式(不含 zstd/brotli/lz4 等
  扩展 codec)。如果你之前用的是 mcmilk 的 TotalCmd.7z,替换后会失去那些扩展格式支持,
  但与 TC 作者官方版行为完全一致。
- 另附 `7z-x86/x64/arm64.dll`(Bundles\Format7zF,即 `7z.dll` 完整版),可用于替换
  7-Zip 本体安装目录中的 `7z.dll`(可选,非 TC 必需)。
- GitHub 会在仓库 **60 天无活动**后自动停用定时 workflow,届时手动 Run 一次即可重新激活。
- 编译产物静态链接 CRT(`/MT`),无运行库依赖;链接子系统版本沿用 mcmilk 的设置
  (x86→5.01、x64→5.02、arm64→6.02),兼容老系统。
