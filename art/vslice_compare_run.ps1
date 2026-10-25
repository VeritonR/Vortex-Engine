param(
	[int]$Seconds = 95,
	[string]$Out = "$PSScriptRoot\..\export\vslice_compare",
	[string]$Game = 'F:\funkin-windows-64bit'
)
# Takes pictures of a song on the original V-Slice game, to compare with the same song on Vortex Engine.
#
# It puts the test mod of "art\vslice_compare_mod" on the game's mods folder, opens the game, waits, closes it, takes the mod out
# again and moves the pictures to -Out. The mod opens the song by itself when the title screen shows up, with botplay on and
# without saving or sending any score, and takes the pictures with the game's own screenshot plugin.
# Which song, from where and when the pictures are taken is set at the top of the mod's script (ClaudeDirectModule.hxc).
#
# The game has to be in front for the whole run: it pauses itself when its window loses the focus.

$mod = Join-Path $Game 'mods\zz_claude_test'
if (Get-Process -Name Funkin -ErrorAction SilentlyContinue) { "Funkin.exe is already open, not starting another"; exit 1 }

$shots = Join-Path $Game 'screenshots'
$before = @()
if (Test-Path $shots) { $before = Get-ChildItem $shots | ForEach-Object { $_.Name } }

New-Item -ItemType Directory -Force $Out | Out-Null
Get-ChildItem $Out -File | ForEach-Object { [System.IO.File]::Delete($_.FullName) }

Copy-Item (Join-Path $PSScriptRoot 'vslice_compare_mod') $mod -Recurse -Force
try
{
	$p = Start-Process -FilePath (Join-Path $Game 'Funkin.exe') -WorkingDirectory $Game -PassThru -RedirectStandardOutput (Join-Path $Out 'stdout.txt') -RedirectStandardError (Join-Path $Out 'stderr.txt')
	$sw = [Diagnostics.Stopwatch]::StartNew()
	while ($sw.Elapsed.TotalSeconds -lt $Seconds -and -not $p.HasExited) { Start-Sleep -Milliseconds 500 }
	if (-not $p.HasExited) { $p.Kill(); "closed after $Seconds s" } else { "exited by itself with " + $p.ExitCode }
	Start-Sleep -Seconds 1
}
finally
{
	# (the game must not be left opening that song every time)
	if (Test-Path $mod) { [System.IO.Directory]::Delete($mod, $true) }
}

$n = 0
if (Test-Path $shots) {
	Get-ChildItem $shots | Where-Object { $before -notcontains $_.Name } | Sort-Object LastWriteTime | ForEach-Object {
		$n++
		Move-Item $_.FullName (Join-Path $Out ("orig_{0:00}{1}" -f $n, $_.Extension)) -Force
	}
	if (-not (Get-ChildItem $shots)) { [System.IO.Directory]::Delete($shots) }
}
"$n pictures in $Out"
