# Builds the Android APK (ARM phones: armv7 and arm64), the same steps used to make the ones tested so far.
# Run it with build_android.bat, at the project's root (double click it).
#
#   build_android.bat            builds the APK
#   build_android.bat -Clean     builds everything again from scratch (if a build ever comes out broken)
#   build_android.bat -Install   also installs it on the phone plugged in by USB (USB debugging on)
#
# What it does:
#  1. Builds again from scratch by itself when Project.xml changed what's compiled since the last build (its defines,
#     libraries...): what was compiled before doesn't match anymore, and the APK would open with "dlopen failed".
#  2. Compiles the game (lime build android), with its files copied again (a renamed file would keep its old copy otherwise).
#  3. Checks the game's library: Lua has to be inside it (otherwise songs with Lua crash on the phone).
#  4. Packs the APK with Gradle (only arm: what an emulator build left for x86 is taken out), and checks that every file of the
#     game is in it with the right name (capital letters count on a phone).
#  5. Copies it to export/VortexEngine-android.apk and opens the folder.

param(
	[switch]$Clean,
	[switch]$Install
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

# Where the tools are (the same as in lime's config, ~/.lime/config.xml)
$javaHome = 'C:\Android\jdk-17.0.21.0.2+1'
$sdk = 'C:\Androidsdk'
$ndkTools = Join-Path $sdk 'ndk\21.4.7075529\toolchains\llvm\prebuilt\windows-x86_64\bin'

$android = Join-Path $root 'export\release\android'
$bin = Join-Path $android 'bin'
$jniLibs = Join-Path $bin 'app\src\main\jniLibs'
$apk = Join-Path $bin 'app\build\outputs\apk\release\VortexEngine-release.apk'
$output = Join-Path $root 'export\VortexEngine-android.apk'
$hashFile = Join-Path $android 'project-xml.hash'

# The game's files as lime lists them (export/.../assets/manifest/default.json, in Haxe's own format), with the names the game
# asks for: on a phone a name is found only with the same capital letters
function Get-AssetPaths($manifestFile) {
	$text = [IO.File]::ReadAllText($manifestFile)
	$paths = New-Object System.Collections.Generic.HashSet[string]
	$pattern = [regex]'y(\d+):assets%2F'
	$index = 0
	while (($found = $pattern.Match($text, $index)).Success) {
		$start = $found.Index + $found.Groups[1].Length + 2
		$value = [uri]::UnescapeDataString($text.Substring($start, [int]$found.Groups[1].Value))
		if ($value -match '\.[A-Za-z0-9]+$') { [void]$paths.Add($value) }
		$index = $start + [int]$found.Groups[1].Value
	}
	return $paths
}

function Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host ''; Write-Host "ERRO: $text" -ForegroundColor Red; exit 1 }

foreach ($path in @($javaHome, $sdk, $ndkTools)) {
	if (-not (Test-Path $path)) { Fail "nao achei $path (o JDK, o SDK ou o NDK do Android)." }
}
if (-not (Get-Command haxelib -ErrorAction SilentlyContinue)) { Fail 'nao achei o haxelib (Haxe precisa estar instalado).' }

$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
# (with this one set, Windows doesn't find gradlew.bat in its own folder)
Remove-Item Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue

# 1. Project.xml changed what's compiled (its defines, libraries, architectures...): from scratch. Its files (<assets>) don't count
$compileLines = Get-Content (Join-Path $root 'Project.xml') | Where-Object {
	$_ -match '<\s*/?\s*(define|undefine|haxedef|haxeflag|haxelib|set|unset|architecture|classpath|source|compilerflag|section)\b'
}
$sha = [Security.Cryptography.SHA256]::Create()
$hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($compileLines | ForEach-Object { $_.Trim() }) -join "`n"))).Replace('-', '')
$lastHash = if (Test-Path $hashFile) { (Get-Content $hashFile -Raw).Trim() } else { '' }
$objDir = Join-Path $android 'obj'
if ($Clean -or ($lastHash -ne '' -and $lastHash -ne $hash)) {
	if (Test-Path $objDir) {
		Step 'Compilando do zero (Project.xml mudou, ou -Clean)'
		Remove-Item -Recurse -Force $objDir
	}
}

# 2. The game. Its files are copied again every time: lime only copies a file when it's newer than the copy it made, so a file
# renamed (or put back from an older copy) would keep the old one under its name. Gradle's own copies of them too
$assetsCopy = Join-Path $bin 'app\src\main\assets\assets'
if (Test-Path $assetsCopy) { Remove-Item -Recurse -Force $assetsCopy }
foreach ($folder in @('assets', 'compressed_assets')) {
	$copies = Join-Path $bin "app\build\intermediates\$folder"
	if (Test-Path $copies) { Remove-Item -Recurse -Force $copies }
}
Step 'Compilando o jogo (lime build android) - a primeira vez demora bastante'
# (lime also tries to pack the APK at the end, and that part can fail on its own: it's done again below. Only an error before it,
# while compiling, stops here; the messages of native programs are only text here, not PowerShell errors)
$ErrorActionPreference = 'Continue'
$limeOutput = & haxelib run lime build android 2>&1 | ForEach-Object { $line = "$_"; Write-Host $line; $line }
$limeCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($limeCode -ne 0) {
	$reachedGradle = @($limeOutput | Where-Object { $_ -match 'gradle|> Task|BUILD FAILED' }).Count -gt 0
	if (-not $reachedGradle) { Fail 'a compilacao do jogo falhou (veja as mensagens acima).' }
	Write-Host '(o lime parou na parte do Gradle, que e feita de novo abaixo)' -ForegroundColor DarkGray
}
$libs = @('arm64-v8a', 'armeabi-v7a') | ForEach-Object { Join-Path $jniLibs "$_\libApplicationMain.so" }

# 2b. Names with other capital letters: Windows doesn't tell "menu.PNG" from "menu.png", so a file of the game whose name changed
# only that way keeps its old name in the build's folder (and in the APK, where the phone doesn't find it). Put back as the game has it
$assetsDir = Join-Path $bin 'app\src\main\assets'
$manifestFile = Join-Path $assetsDir 'manifest\default.json'
if (-not (Test-Path $manifestFile)) { Fail "nao achei a lista de arquivos do jogo ($manifestFile)." }
$wanted = Get-AssetPaths $manifestFile
$onDisk = @{}
Get-ChildItem -Path (Join-Path $assetsDir 'assets') -Recurse -File | ForEach-Object {
	$relative = $_.FullName.Substring($assetsDir.Length + 1).Replace('\', '/')
	$onDisk[$relative.ToLowerInvariant()] = $_
}
$renamed = 0
foreach ($path in $wanted) {
	$file = $onDisk[$path.ToLowerInvariant()]
	if ($file -eq $null) { continue }
	$wantedName = Split-Path $path -Leaf
	if ($file.Name -cne $wantedName) {
		# (in two steps: a rename that only changes capital letters isn't done by Windows)
		$temporary = $file.FullName + '.renaming'
		Move-Item -LiteralPath $file.FullName -Destination $temporary
		Move-Item -LiteralPath $temporary -Destination (Join-Path $file.DirectoryName $wantedName)
		Write-Host "nome corrigido: $path"
		$renamed++
	}
}
if ($renamed -gt 0) {
	# (Gradle's own copies of them would keep the old names too)
	foreach ($folder in @('assets', 'compressed_assets')) {
		$copies = Join-Path $bin "app\build\intermediates\$folder"
		if (Test-Path $copies) { Remove-Item -Recurse -Force $copies }
	}
}

# 3. The library: Lua inside it, nothing missing
Step 'Conferindo a biblioteca do jogo'
$nm = Join-Path $ndkTools 'llvm-nm.exe'
foreach ($lib in $libs) {
	if (-not (Test-Path $lib)) { Fail "nao achei $lib (a compilacao falhou?)" }
	$missing = & $nm -D --undefined-only $lib
	if ($LASTEXITCODE -ne 0) { Fail "nao consegui ler $lib" }
	$lua = @($missing | Where-Object { $_ -match '\b(lua|luaL)_' }).Count
	$hx = @($missing | Where-Object { $_ -match '_hx_pos' }).Count
	$abi = Split-Path (Split-Path $lib -Parent) -Leaf
	if ($lua -gt 0) { Fail "$abi : o Lua ficou fora da biblioteca ($lua funcoes). Rode de novo com -Clean." }
	if ($hx -gt 0) { Fail "$abi : a biblioteca esta incompleta (sobras de uma compilacao antiga). Rode de novo com -Clean." }
	Write-Host "$abi ok"
}
Set-Content -Path $hashFile -Value $hash

# 4. The APK, for ARM phones only
foreach ($abi in @('x86', 'x86_64')) {
	$extra = Join-Path $jniLibs $abi
	if (Test-Path $extra) { Remove-Item -Recurse -Force $extra }
}
Step 'Montando o APK (Gradle)'
Push-Location $bin
try {
	$ErrorActionPreference = 'Continue'
	& cmd /c '.\gradlew.bat assembleRelease --no-daemon'
	$ErrorActionPreference = 'Stop'
	if ($LASTEXITCODE -ne 0) { Fail 'o Gradle falhou (veja as mensagens acima).' }
}
finally { Pop-Location }
if (-not (Test-Path $apk)) { Fail "o APK nao foi criado ($apk)." }

# 4b. Every file of the game is in the APK with the name the game asks for
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($apk)
try {
	$inApk = New-Object System.Collections.Generic.HashSet[string]
	foreach ($entry in $zip.Entries) { [void]$inApk.Add($entry.FullName) }
}
finally { $zip.Dispose() }
$absent = @($wanted | Where-Object { -not $inApk.Contains('assets/' + $_) })
if ($absent.Count -gt 0) {
	$absent | Select-Object -First 15 | ForEach-Object { Write-Host "falta no APK: $_" -ForegroundColor Yellow }
	Fail "$($absent.Count) arquivo(s) do jogo nao estao no APK com o nome certo. Rode de novo com -Clean."
}
Write-Host "$($wanted.Count) arquivos do jogo conferidos no APK"

# 5. Where it's easy to find
Copy-Item $apk $output -Force
$size = [math]::Round((Get-Item $output).Length / 1MB, 1)
Step "Pronto: $output ($size MB)"

if ($Install) {
	$adb = Join-Path $sdk 'platform-tools\adb.exe'
	Step 'Instalando no celular (USB)'
	& $adb install -r $output
	if ($LASTEXITCODE -ne 0) { Write-Host 'Nao deu para instalar: o celular esta conectado, com a Depuracao USB ligada?' -ForegroundColor Yellow }
}
else {
	Start-Process explorer.exe "/select,`"$output`""
}
