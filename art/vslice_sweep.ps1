# Opens every song of the V-Slice content that comes with the game, one after the other, and writes down what went wrong on each:
# the errors of their scripts ("hxc_errors.txt"), crashes and the game hanging. It also keeps pictures of each one.
# It uses the game's own way of opening a song from the command line (see source/backend/DirectPlay.hx), with botplay.
#
#   powershell -File art\vslice_sweep.ps1 -Out C:\temp\sweep
#
# -Out      Folder for the results: "summary.txt" and a folder for each song, with its pictures and its "hxc_errors.txt".
# -Quit     Seconds each song is left open (40).
# -Rate     How fast the songs are played (2).
# -Shots    Seconds at which pictures are taken ("8,30").
# -Time     Seconds of the song to start from (0), to see how they end without sitting through them.
# -Only     Only these, by "song-variation" ("stress-pico,spaghetti-default").
# -Cutscenes  Plays the songs like the menus do. Without it they're played the way the chart editor tests a chart,
#             which is what V-Slice scripts look at to skip their cutscenes.
# -Bin      Folder of the built game.
param(
	[Parameter(Mandatory = $true)][string]$Out,
	[int]$Quit = 40,
	[string]$Rate = '2',
	[string]$Shots = '8,30',
	[string]$Time = '0',
	[string]$Only = '',
	[switch]$Cutscenes,
	[string]$Bin = (Join-Path $PSScriptRoot '..\export\release\windows\bin')
)

# song | variation | difficulty | player of Character Select that has it
$songs = @(
	'blammed|erect|erect|bf', 'blammed|pico|hard|pico', 'bopeebo|erect|erect|bf', 'bopeebo|pico|hard|pico',
	'cocoa|erect|erect|bf', 'cocoa|pico|hard|pico', 'dadbattle|erect|erect|bf', 'dadbattle|pico|hard|pico',
	'darnell|bf|hard|bf', 'darnell|erect|erect|pico', 'eggnog|erect|erect|bf', 'eggnog|pico|hard|pico',
	'fresh|erect|erect|bf', 'fresh|pico|hard|pico', 'guns|pico|hard|pico', 'high|erect|erect|bf', 'lit-up|bf|hard|bf',
	'philly-nice|erect|erect|bf', 'philly-nice|pico|hard|pico', 'pico|erect|erect|bf', 'pico|pico|hard|pico',
	'roses|erect|erect|bf', 'roses|pico|hard|pico', 'satin-panties|erect|erect|bf', 'senpai|erect|erect|bf', 'senpai|pico|hard|pico',
	'south|erect|erect|bf', 'south|pico|hard|pico', 'spaghetti|default|hard|bf', 'spookeez|erect|erect|bf', 'spookeez|pico|hard|pico',
	'stress|pico|hard|pico', 'thorns|erect|erect|bf', 'ugh|erect|erect|bf', 'ugh|pico|hard|pico'
)

$Bin = (Resolve-Path $Bin).Path
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = (Resolve-Path $Out).Path
$summary = Join-Path $Out 'summary.txt'
'' | Set-Content $summary

foreach ($entry in $songs) {
	$parts = $entry.Split('|')
	$name = $parts[0] + '-' + $parts[1]
	if ($Only -ne '' -and ($Only.Split(',') -notcontains $name)) { continue }

	$songDir = Join-Path $Out $name
	New-Item -ItemType Directory -Force $songDir | Out-Null
	Get-ChildItem $songDir -Filter *.png | ForEach-Object { [System.IO.File]::Delete($_.FullName) }

	$gameArgs = @("--song=$($parts[0])", '--mod=base', "--difficulty=$($parts[2])", "--player=$($parts[3])", '--botplay', '--volume=0.03',
		"--rate=$Rate", "--shots=$Shots", "--quit=$Quit", "--shotdir=$songDir")
	if ($Time -ne '0') { $gameArgs += "--time=$Time" }
	if (-not $Cutscenes) { $gameArgs += '--charting' }

	Set-Location $Bin
	$start = Get-Date
	$process = Start-Process -FilePath '.\VortexEngine.exe' -ArgumentList $gameArgs -PassThru
	$handle = $process.Handle
	if ($process.WaitForExit(($Quit + 40) * 1000)) { $result = 'exit ' + ('{0:X}' -f $process.ExitCode) }
	else {
		# (what the game was doing is kept: the next song starts that file over)
		$result = 'HUNG (closed)'
		Copy-Item (Join-Path $Bin 'last_steps.txt') (Join-Path $songDir 'last_steps.txt') -Force -ErrorAction SilentlyContinue
		$process.Kill()
	}

	$lines = @("=== $name : $result after " + [math]::Round(((Get-Date) - $start).TotalSeconds) + 's, pictures ' + (Get-ChildItem $songDir -Filter *.png).Count)

	$crash = Get-ChildItem (Join-Path $Bin 'crash') -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $start } | Select-Object -First 1
	if ($crash) {
		$text = Get-Content $crash.FullName | Where-Object { $_ -ne '' }
		$lines += 'CRASH: ' + (($text | Where-Object { $_ -match 'Uncaught' }) -join ' ') + ' :: ' + (($text | Select-Object -First 3) -join ' <- ')
	}

	$errors = Join-Path $Bin 'hxc_errors.txt'
	if ((Test-Path $errors) -and ((Get-Item $errors).LastWriteTime -ge $start)) {
		Copy-Item $errors (Join-Path $songDir 'hxc_errors.txt') -Force
		$inErrors = $false
		foreach ($line in (Get-Content $errors)) {
			if ($line -match '^\[') { $inErrors = ($line -match '^\[Errors\]' -or $line -match '^\[Imports that are not supported\]') }
			elseif ($inErrors -and $line.Trim() -ne '') { $lines += '  ' + ($line -replace 'assets/vslice/scripts/', '') }
		}
	}
	else { $lines += '  (the scripts were not loaded)' }

	$lines | Add-Content $summary
	$lines
}
