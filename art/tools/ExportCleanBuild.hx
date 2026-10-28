package;

import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Makes a copy of the built game for people making mods with Vortex Engine: everything the engine needs to work, without the songs
 * and weeks of the base game (Psych's and V-Slice's), so only the mod's own songs show up in Freeplay and Story Mode.
 *
 * It runs with Haxe itself (the one that builds the game), nothing else has to be installed. From the engine's folder:
 *
 *   haxe art/export_clean_build.hxml                                    (from export/release/windows/bin to export/clean)
 *   haxe art/export_clean_build.hxml <game folder> <output folder> [--zip] [--dry]
 *
 * or, on Windows, double click art/export_clean_build.bat (it takes the same options).
 *
 * What's kept: the engine, the characters, the stages (and their images), the note skins, the menus, Freeplay's DJs, Character Select,
 * the results screen, the sounds and music of the menus, and the V-Slice base content mods use (characters, stages, note styles...).
 *
 * What's left out:
 *   - Psych's songs: their audio (assets/songs), their charts (assets/shared/data/<song>), the weeks (assets/shared/weeks)
 *     and the cutscene videos (assets/videos)
 *   - V-Slice's base songs: their audio, charts and levels (assets/vslice/songs, data/songs, data/levels),
 *     their scripts (scripts/songs) and their videos (assets/vslice/videos)
 *   - what's only on this computer: the mods folder (a clean one with its readme and template takes its place), the chart
 *     editor's backups, the mods list, the logs and the errors of the scripts
 *
 * The game has to be built first (lime build windows). The output folder is made again from nothing each time: if it has something
 * an export didn't put there (a file saved in it, a mod in its mods folder), it stops and says what, unless --force is given.
 *
 *   --zip    also makes <output folder>.zip
 *   --dry    only shows what would be copied and left out
 *   --force  deletes what's in the output folder even if it isn't from an export
 */
class ExportCleanBuild
{
	// Folders and files of the game folder that aren't copied at all (relative to it, with "/")
	static final SKIP_ROOT:Array<String> = [
		'mods', 'backups', 'logs', 'crash', 'screenshots',
		'modsList.txt', 'last_steps.txt', 'hxc_errors.txt', 'hxc_menu_errors.txt',
	];
	// Inside assets: whole folders that are songs only
	static final SKIP_DIRS:Array<String> = [
		'assets/songs',
		'assets/vslice/songs',
		'assets/vslice/data/songs',
		'assets/vslice/data/levels',
		'assets/vslice/scripts/songs',
		'assets/vslice/videos',
	];
	// Folders of assets/shared/data that aren't songs (everything else with a chart in it is one)
	static final DATA_KEEP:Array<String> = ['players', 'ui', 'stickerpacks'];

	static var SRC:String;
	static var DST:String;
	static var DRY:Bool;

	static var copiedFiles:Int = 0;
	static var copiedBytes:Float = 0.0;
	static var leftOut:Map<String, {count:Int, bytes:Float}> = [];

	static function main()
	{
		var root:String = Tools.engineRoot();
		var all:Array<String> = Sys.args();
		var args:Array<String> = [for (a in all) if (!a.startsWith('--')) a];
		SRC = Tools.full(args.length > 0 ? args[0] : '$root/export/release/windows/bin');
		DST = Tools.full(args.length > 1 ? args[1] : '$root/export/clean');
		DRY = all.contains('--dry');
		var zip:Bool = all.contains('--zip');

		if (!FileSystem.exists(SRC) || !FileSystem.isDirectory(SRC) || !hasGame(SRC))
			Tools.fail('There is no built game in "$SRC" (build it first: lime build windows)');
		if (Tools.samePath(SRC, DST) || Tools.inside(SRC, DST))
			Tools.fail('The output folder can\'t be the game folder or have it inside');

		// (the output folder is made again from nothing: what's in it has to be from an export, or from running the game in it)
		if (FileSystem.exists(DST) && !all.contains('--force'))
		{
			var foreign:Array<String> = notFromExport(DST, '$root/example_mods');
			if (foreign.length > 0)
				Tools.fail('The output folder "$DST" has things that aren\'t from an export, they\'d be lost:\n  '
					+ foreign.join('\n  ') + '\nMove them out of it, choose another output folder, or add --force to delete them.');
		}

		if (!DRY)
		{
			if (FileSystem.exists(DST)) Tools.deleteFolder(DST);
			FileSystem.createDirectory(DST);
		}
		walk('');

		// a clean mods folder, with the readme and the template of a mod
		if (!DRY)
		{
			var mods:String = '$DST/mods';
			FileSystem.createDirectory(mods);
			var example:String = '$root/example_mods';
			if (FileSystem.isDirectory(example))
				for (f in FileSystem.readDirectory(example))
					if (!FileSystem.isDirectory('$example/$f')) File.copy('$example/$f', '$mods/$f');
			// (empty folders for the songs' audio and the weeks, where the game looks for them)
			FileSystem.createDirectory('$DST/assets/songs');
			FileSystem.createDirectory('$DST/assets/shared/weeks');
			File.saveContent('$DST/assets/shared/weeks/weekList.txt', '');
		}

		Sys.println('Game folder:   ' + SRC);
		Sys.println('Output folder: ' + DST + (DRY ? '  (dry run: nothing was written)' : ''));
		Sys.println('Copied: $copiedFiles files, ' + Tools.mb(copiedBytes));
		var reasons:Array<String> = [for (r in leftOut.keys()) r];
		reasons.sort((a, b) -> leftOut[b].bytes > leftOut[a].bytes ? 1 : (leftOut[b].bytes < leftOut[a].bytes ? -1 : 0));
		for (r in reasons)
			Sys.println('Left out ($r): ${leftOut[r].count}, ' + Tools.mb(leftOut[r].bytes));

		if (zip && !DRY)
		{
			var archive:String = DST + '.zip';
			Sys.println('Making the zip...');
			ZipMaker.folder(DST, archive);
			Sys.println('Zip: $archive (' + Tools.mb(Tools.fileSize(archive)) + ')');
		}
	}

	// What's in an old output folder that neither an export nor the game (its logs, mods list...) put there: a file someone saved in it
	static function notFromExport(folder:String, exampleMods:String):Array<String>
	{
		var fromGame:Array<String> = FileSystem.readDirectory(SRC);
		var template:Array<String> = Tools.isDir(exampleMods) ? FileSystem.readDirectory(exampleMods) : [];
		var foreign:Array<String> = [];
		for (name in FileSystem.readDirectory(folder))
		{
			if (name == 'mods')
			{
				// (only the readme and the template go in it: a mod in there is someone's)
				if (FileSystem.isDirectory('$folder/mods'))
					for (inside in FileSystem.readDirectory('$folder/mods'))
						if (!template.contains(inside)) foreign.push('mods/$inside');
				continue;
			}
			if (!fromGame.contains(name) && !SKIP_ROOT.contains(name)) foreign.push(name);
		}
		return foreign;
	}

	// (the game's program: VortexEngine.exe on Windows, VortexEngine on Linux and Mac)
	static function hasGame(folder:String):Bool
	{
		for (f in FileSystem.readDirectory(folder))
			if (f.toLowerCase().endsWith('.exe') || f == 'VortexEngine' || f == 'VortexEngine.app') return true;
		return false;
	}

	// A folder of assets/shared/data that has a chart: <name>.json, <name>-<difficulty>.json or events.json
	static function isSongData(folder:String):Bool
	{
		var name:String = Tools.baseName(folder);
		if (DATA_KEEP.contains(name)) return false;
		var low:String = name.toLowerCase();
		for (f in FileSystem.readDirectory(folder))
		{
			var file:String = f.toLowerCase();
			if (file == 'events.json' || file == '$low.json' || (file.startsWith('$low-') && file.endsWith('.json')))
				return true;
		}
		return false;
	}

	// Why a file or folder (relative path, with "/") is left out, or null
	static function skipped(rel:String, full:String):String
	{
		if (SKIP_ROOT.contains(rel.split('/')[0])) return 'only on this computer';
		if (SKIP_DIRS.contains(rel)) return 'base songs';
		if (rel.startsWith('assets/shared/weeks/')) return 'base weeks';
		if (rel.startsWith('assets/shared/data/') && rel.split('/').length == 4 && FileSystem.isDirectory(full) && isSongData(full))
			return 'base song chart';
		var low:String = rel.toLowerCase();
		if (rel.startsWith('assets/videos/') && low.endsWith('.mp4')) return 'base cutscene';
		if (low.endsWith('.bkp')) return 'chart backup';
		return null;
	}

	static function walk(relDir:String)
	{
		var srcDir:String = relDir == '' ? SRC : '$SRC/$relDir';
		var names:Array<String> = FileSystem.readDirectory(srcDir);
		names.sort(Tools.compare);
		for (name in names)
		{
			var rel:String = relDir == '' ? name : '$relDir/$name';
			var full:String = '$srcDir/$name';
			var reason:String = skipped(rel, full);
			if (reason != null)
			{
				var entry = leftOut.get(reason);
				if (entry == null) leftOut.set(reason, entry = {count: 0, bytes: 0.0});
				entry.count++;
				entry.bytes += Tools.sizeOf(full);
				continue;
			}
			if (FileSystem.isDirectory(full))
			{
				if (!DRY) FileSystem.createDirectory('$DST/$rel');
				walk(rel);
			}
			else
			{
				if (!DRY) File.copy(full, '$DST/$rel');
				copiedFiles++;
				copiedBytes += Tools.fileSize(full);
			}
		}
	}
}
