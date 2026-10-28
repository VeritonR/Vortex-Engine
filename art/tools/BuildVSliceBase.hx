package;

import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Builds the folder with the content of V-Slice's base game the engine doesn't have in Psych's format:
 * the Erect remixes, the Pico and Boyfriend mixes and the LE SSERAFIM week. Everything stays in V-Slice's own format.
 *
 * It's part of the base game: the output folder is "assets/base_game/vslice", which the build takes along with the rest of the base game's
 * assets (see backend.PolymodCompat.BASE_MOD for how it's played).
 *
 * It runs with Haxe itself (the one that builds the game), nothing else has to be installed. From the engine's folder:
 *
 *   haxe art/build_vslice_base.hxml <V-Slice assets> <engine assets> <output folder> [--dry] [--list=FILE]
 *   haxe art/build_vslice_base.hxml "F:/Funkin/assets" "F:/Vortex Engine/assets" "F:/Vortex Engine/assets/base_game/vslice"
 */
class BuildVSliceBase
{
	static var SRC:String;
	static var ENG:String;
	static var DST:String;

	static final WEEK_LIBS:Array<String> = ['week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1', 'sserafim', 'tutorial'];
	static final LIBS:Array<String> = ['preload', 'shared'].concat(WEEK_LIBS);
	static final SKIP_SONGS:Array<String> = ['test'];
	static final SKIP_EXT:Array<String> = ['.mp3', '.fla', '.md', '.txt~'];

	static var copied:Map<String, String> = []; // destination (relative) -> source
	static var copiedOrder:Array<String> = []; // (in the order they were found: on Windows, the first of two names that differ only in case is the one that stays)
	static var skippedSame:Int = 0;
	static var skippedEngine:Array<String> = [];
	static var sizes:Map<String, Float> = [];
	static var sizeOrder:Array<String> = [];

	static var pendingChars:Array<String> = [];
	static var doneChars:Map<String, Bool> = [];
	static var seenStrings:Map<String, Bool> = [];

	static function main()
	{
		var all:Array<String> = Sys.args();
		var args:Array<String> = [for (a in all) if (!a.startsWith('--')) a];
		if (args.length < 3)
			Tools.fail('Usage: haxe art/build_vslice_base.hxml <V-Slice assets> <engine assets> <output folder> [--dry] [--list=FILE]');
		SRC = folderArg(args[0]);
		ENG = folderArg(args[1]);
		DST = folderArg(args[2]);
		var dry:Bool = all.contains('--dry');

		// ---------------------------------------------------------------------------------------------
		// Songs
		// ---------------------------------------------------------------------------------------------
		var songsRoot:String = '$SRC/preload/data/songs';
		var engineSongs:Map<String, Bool> = [];
		for (root in ['$ENG/shared/data', '$ENG/base_game/shared/data'])
		{
			if (!isDir(root)) continue;
			for (d in FileSystem.readDirectory(root))
				if (isDir('$root/$d') && Lambda.exists(FileSystem.readDirectory('$root/$d'), f -> f.endsWith('.json')))
					engineSongs.set(simple(d), true);
		}

		var included:Array<Array<String>> = []; // [song, variation]
		var usedChars:Array<String> = [];
		var usedStages:Array<String> = [];
		var songIds:Array<String> = [];
		for (song in sorted(FileSystem.readDirectory(songsRoot)))
		{
			if (SKIP_SONGS.contains(song)) continue;
			var defaultMeta:String = '$songsRoot/$song/$song-metadata.json';
			if (!isFile(defaultMeta)) continue;

			var variations:Array<String> = [];
			var listed:Array<Dynamic> = Tools.readJson(defaultMeta).playData.songVariations;
			if (listed != null) for (v in listed) variations.push(v);
			// the default charts are only for the songs the engine doesn't have at all
			if (!engineSongs.exists(simple(song))) variations.insert(0, 'default');

			for (variation in variations)
			{
				var suffix:String = variation == 'default' ? '' : '-$variation';
				var metaKey:String = 'data/songs/$song/$song-metadata$suffix.json';
				var chartKey:String = 'data/songs/$song/$song-chart$suffix.json';
				if (!isFile('$SRC/preload/$metaKey') || !isFile('$SRC/preload/$chartKey'))
				{
					Sys.println('  missing files for $song $variation');
					continue;
				}

				add('preload', metaKey, 'charts', true);
				add('preload', chartKey, 'charts', true);
				var meta:Dynamic = resolveJson('$SRC/preload/$metaKey', 'song data');
				var play:Dynamic = meta.playData;

				// the health icons the chart changes to along the song, which aren't the ones of its characters
				var events:Array<Dynamic> = Tools.readJson('$SRC/preload/$chartKey').events;
				if (events != null)
					for (event in events)
					{
						var value:Dynamic = event.v;
						if (event.e == 'SetHealthIcon' && isObject(value) && truthy(value.id))
							resolve('icons/icon-' + value.id, 'icons');
					}
				var characters:Dynamic = play.characters != null ? play.characters : {};
				for (role in ['player', 'opponent', 'girlfriend'])
				{
					var id:Dynamic = Reflect.field(characters, role);
					if (truthy(id) && !usedChars.contains(id)) usedChars.push(id);
				}
				if (truthy(play.stage) && !usedStages.contains(play.stage)) usedStages.push(play.stage);

				for (name in songAudio(song, variation, characters))
				{
					var src:String = '$SRC/songs/$song/$name.ogg';
					var dest:String = 'songs/$song/$name.ogg';
					if (!copied.exists(dest))
					{
						setCopied(dest, src);
						addSize('song audio', Tools.fileSize(src));
					}
				}

				included.push([song, variation]);
				if (!songIds.contains(song)) songIds.push(song);
			}
		}

		// ---------------------------------------------------------------------------------------------
		// Levels: only the ones with a song that's all new
		// ---------------------------------------------------------------------------------------------
		var newSongs:Array<String> = [for (pair in included) if (pair[1] == 'default') pair[0]];
		var levels:Array<String> = [];
		for (file in sorted(FileSystem.readDirectory('$SRC/preload/data/levels')))
		{
			var data:Dynamic = Tools.readJson('$SRC/preload/data/levels/$file');
			var songs:Array<String> = data.songs != null ? data.songs : [];
			if (Lambda.exists(songs, s -> newSongs.contains(s)))
			{
				add('preload', 'data/levels/$file', 'data', true);
				resolveJson('$SRC/preload/data/levels/$file', 'story menu');
				levels.push(file.substr(0, file.length - 5));
			}
		}

		// ---------------------------------------------------------------------------------------------
		// Scripts: the ones of the songs, stages and characters that are included, plus what they share
		// ---------------------------------------------------------------------------------------------
		var scriptsRoot:String = '$SRC/preload/scripts';
		var scriptInfo:Map<String, ScriptInfo> = [];
		var scriptPaths:Array<String> = [];
		for (rel in walkFiles(scriptsRoot))
		{
			if (!rel.endsWith('.hxc')) continue;
			var path:String = '$scriptsRoot/$rel';
			var code:String = Tools.readText(path);
			var variation:EReg = ~/variation\s*:\s*['"]([^'"]+)['"]/;
			scriptInfo.set(path, {
				declared: findAll(~/^\s*(?:final\s+)?class\s+(\w+)/gm, code),
				extended: [for (e in findAll(~/^\s*(?:final\s+)?class\s+\w+\s+extends\s+([\w.]+)/gm, code)) e.split('.').pop()],
				ids: findAll(~/super\(\s*['"]([^'"]+)['"]/g, code),
				variation: variation.match(code) ? variation.matched(1) : null,
			});
			scriptPaths.push(path);
		}

		var wanted:Map<String, Bool> = [];
		var includedSongs:Array<String> = [for (pair in included) pair[0]];
		var includedPairs:Array<String> = [for (pair in included) pair[0] + '\n' + pair[1]];
		for (path in scriptPaths)
		{
			var info:ScriptInfo = scriptInfo[path];
			var rel:String = path.substr(scriptsRoot.length + 1);
			var top:String = rel.split('/')[0];
			if (top == 'players') continue; // the engine has its own cards, DJ and results for the base game's players
			if (top == 'songs')
			{
				// a script made for one variation is only for it, the others are for every variation of their song
				if (Lambda.exists(info.ids, i -> includedSongs.contains(i))
					&& (info.variation == null || (info.ids.length > 0 && includedPairs.contains(info.ids[0] + '\n' + info.variation))))
					wanted.set(path, true);
			}
			else if (top == 'stages')
			{
				if (rel.contains('/props/') || Lambda.exists(info.ids, i -> usedStages.contains(i))) wanted.set(path, true);
			}
			else
				wanted.set(path, true); // characters, note kinds, dialogue, levels, shaders: small, and found by their id when needed
		}

		// and the classes those extend, wherever they are
		var changed:Bool = true;
		while (changed)
		{
			changed = false;
			var needed:Array<String> = [];
			for (path in wanted.keys()) needed = needed.concat(scriptInfo[path].extended);
			for (path in scriptPaths)
				if (!wanted.exists(path) && !path.contains('players/') && Lambda.exists(scriptInfo[path].declared, c -> needed.contains(c)))
				{
					wanted.set(path, true);
					changed = true;
				}
		}

		for (path in sorted([for (p in wanted.keys()) p]))
		{
			add('preload', path.substr('$SRC/preload/'.length), 'scripts', true);
			resolveScript(path, 'script assets');
		}

		// ---------------------------------------------------------------------------------------------
		// Stages and characters
		// ---------------------------------------------------------------------------------------------
		for (stage in usedStages)
		{
			var key:String = 'data/stages/$stage.json';
			if (add('preload', key, 'data', true)) resolveJson('$SRC/preload/$key', 'stage art');
			else Sys.println('  stage not found: $stage');
		}

		pendingChars = usedChars.concat(pendingChars);
		while (pendingChars.length > 0)
		{
			var char:String = pendingChars.shift();
			if (doneChars.exists(char)) continue;
			doneChars.set(char, true);
			var key:String = 'data/characters/$char.json';
			if (!add('preload', key, 'data', true))
			{
				Sys.println('  character not found: $char');
				continue;
			}
			var data:Dynamic = resolveJson('$SRC/preload/$key', 'character art');
			var healthIcon:Dynamic = data != null ? data.healthIcon : null;
			var icon:String = (isObject(healthIcon) && truthy(healthIcon.id)) ? healthIcon.id : char;
			for (name in ['icons/icon-$icon', 'freeplay/icons/${icon}pixel', 'freeplay/icons/${char}pixel'])
				resolve(name, 'icons');
		}

		// the art of the weeks the stages are from goes whole: stage scripts build many of their paths as they go
		for (lib in WEEK_LIBS)
			addTree(lib, '', 'week art');

		// ---------------------------------------------------------------------------------------------
		var variationNames:Array<String> = [];
		for (pair in included) if (!variationNames.contains(pair[1])) variationNames.push(pair[1]);
		var scriptCount:Int = Lambda.count(wanted);
		var copiedCount:Int = Lambda.count(copied);
		Sys.println('variations: ${included.length}  (' + sorted(variationNames).join(', ') + ')');
		Sys.println('songs: ' + songIds.join(', '));
		Sys.println('new levels: ' + pyList(levels));
		Sys.println('stages: ' + pyList(usedStages));
		Sys.println('characters: ' + Lambda.count(doneChars));
		Sys.println('scripts: $scriptCount of ' + scriptPaths.length);
		Sys.println('files: $copiedCount, the same as the engine\'s (left out): $skippedSame, different from the engine\'s (left out, the engine\'s is used): ' + skippedEngine.length);
		var total:Float = 0.0;
		var groups:Array<String> = sizeOrder.copy();
		haxe.ds.ArraySort.sort(groups, (a, b) -> sizes[b] > sizes[a] ? 1 : (sizes[b] < sizes[a] ? -1 : 0));
		for (group in groups)
		{
			Sys.println('  ' + group.rpad(' ', 16) + ' ' + Tools.oneDecimal(sizes[group] / 1e6).lpad(' ', 7) + ' MB');
			total += sizes[group];
		}
		Sys.println('  ' + 'TOTAL'.rpad(' ', 16) + ' ' + Tools.oneDecimal(total / 1e6).lpad(' ', 7) + ' MB');
		if (skippedEngine.length > 0)
		{
			var list:Array<String> = sorted(skippedEngine);
			Sys.println('engine files kept over V-Slice\'s: ' + list.slice(0, 40).join(', ') + ' ' + (list.length > 40 ? '...' : ''));
		}

		// (--list=FILE writes down every file that goes in, to compare with what's there)
		var destinations:Array<String> = sorted([for (d in copied.keys()) d]);
		for (arg in all)
			if (arg.startsWith('--list='))
				File.saveContent(arg.substr(7), destinations.join('\n') + '\n');

		if (dry) return;

		if (isDir(DST)) Tools.emptyFolder(DST); // (what's inside, the folder itself can be in use)
		else FileSystem.createDirectory(DST);
		for (dest in copiedOrder)
		{
			var full:String = '$DST/$dest';
			makeFolders(full);
			File.copy(copied[dest], full);
		}
		File.saveContent('$DST/_polymod_meta.json', META);
		File.saveContent('$DST/_contents.txt', 'Made out of the assets of Friday Night Funkin\' (V-Slice) with a script, only what the engine does not already have.\n\n'
			+ 'Song variations:\n' + [for (pair in included) '  ${pair[0]} (${pair[1]})'].join('\n') + '\n\nNew weeks: ' + levels.join(', ') + '\n');
		Sys.println('written to $DST');
	}

	static final META:String = '{
  "title": "Friday Night Funkin\' - Erect, Pico Mixes and LE SSERAFIM",
  "description": "The songs of the base game the engine doesn\'t have in Psych\'s format: the Erect remixes, the Pico and Boyfriend mixes and the LE SSERAFIM week. Kept in V-Slice\'s own format.",
  "contributors": [
    {
      "name": "The Funkin\' Crew Inc."
    }
  ],
  "api_version": "0.8.0",
  "mod_version": "1.0.0",
  "id": "funkin-vslice-base",
  "license": "Apache-2.0"
}
';

	// ---------------------------------------------------------------------------------------------
	// Copying
	// ---------------------------------------------------------------------------------------------
	static function enginePath(key:String):String
	{
		for (root in ['shared', 'base_game/shared'])
		{
			var p:String = '$ENG/$root/$key';
			if (isFile(p)) return p;
		}
		return null;
	}

	/**
	 * Copies a file of a V-Slice library, unless the engine already has the same thing under the same name.
	 */
	static function add(lib:String, key:String, group:String, force:Bool = false):Bool
	{
		var src:String = '$SRC/$lib/$key';
		if (!isFile(src) || Lambda.exists(SKIP_EXT, e -> key.toLowerCase().endsWith(e))) return false;

		var dest:String = lib == 'preload' ? key : '$lib/$key';
		if (copied.exists(dest)) return true;

		var eng:String = enginePath(key);
		if (eng != null)
		{
			if (Tools.fileSize(eng) == Tools.fileSize(src) && Tools.md5(eng) == Tools.md5(src))
			{
				skippedSame++;
				return true;
			}
			if (!force)
			{
				skippedEngine.push(key);
				return true;
			}
		}

		setCopied(dest, src);
		addSize(group, Tools.fileSize(src));
		return true;
	}

	static function addTree(lib:String, folder:String, group:String, force:Bool = false):Bool
	{
		var root:String = folder != '' ? '$SRC/$lib/$folder' : '$SRC/$lib';
		if (!isDir(root)) return false;
		for (rel in walkFiles(root))
			add(lib, folder != '' ? '$folder/$rel' : rel, group, force);
		return true;
	}

	static function setCopied(dest:String, src:String)
	{
		copied.set(dest, src);
		copiedOrder.push(dest);
	}

	static function addSize(group:String, size:Float)
	{
		if (!sizes.exists(group))
		{
			sizes.set(group, 0.0);
			sizeOrder.push(group);
		}
		sizes.set(group, sizes[group] + size);
	}

	// ---------------------------------------------------------------------------------------------
	// What a text refers to: an image, a texture atlas, a sound, a music, a video, another data file
	// ---------------------------------------------------------------------------------------------
	static function resolve(text:Dynamic, group:String)
	{
		if (!Std.isOfType(text, String)) return;
		var text:String = text;
		if (text.length < 2 || text.length > 120 || text.contains('\n')) return;
		var key:String = (text.contains(':') && !text.startsWith('#')) ? text.substr(text.indexOf(':') + 1) : text;
		key = stripSlashes(key.trim());
		if (key == '' || seenStrings.exists(key) || (key.contains(' ') && !key.contains('/') && key.length > 40)) return;
		seenStrings.set(key, true);
		var isCharacterArt:Bool = key.startsWith('characters/') || key.contains('/characters/');

		for (lib in LIBS)
		{
			var base:String = '$SRC/$lib';
			// images, with what goes along with them
			if (isFile('$base/images/$key.png'))
				for (ext in ['.png', '.xml', '.txt', '.json'])
					add(lib, 'images/$key$ext', group, isCharacterArt);
			if (isDir('$base/images/$key') && isFile('$base/images/$key/Animation.json'))
				addTree(lib, 'images/$key', group, isCharacterArt);
			// sounds: the one asked for, and the numbered ones scripts pick at random
			for (folder in ['sounds', 'music'])
			{
				if (isFile('$base/$folder/$key.ogg')) add(lib, '$folder/$key.ogg', group);
				var keyFolder:String = dirName(key);
				var parent:String = keyFolder != '' ? '$base/$folder/$keyFolder' : '$base/$folder';
				var name:String = baseName(key);
				if (isDir(parent) && name != '')
				{
					var numbered:EReg = new EReg('^' + escapeRegex(name) + '-?\\d+\\.ogg$', '');
					for (f in FileSystem.readDirectory(parent))
						if (numbered.match(f))
							add(lib, normalize(keyFolder != '' ? '$folder/$keyFolder/$f' : '$folder/$f'), group);
				}
			}
			if (isDir('$base/music/$key'))
				addTree(lib, 'music/$key', group);
			// whole files given with their extension
			if (extension(key) != '' && isFile('$base/$key')) add(lib, key, group);
		}

		// videos are outside of the libraries
		for (name in [key, '$key.mp4', '$key.mkv', '$key-censored.mp4', '$key-censored.mkv'])
		{
			var src:String = '$SRC/videos/videos/$name';
			if (isFile(src) && extension(name) != '')
			{
				var dest:String = 'videos/$name';
				if (!copied.exists(dest) && !isFile('$ENG/videos/$name'))
				{
					setCopied(dest, src);
					addSize('videos', Tools.fileSize(src));
				}
			}
		}

		// data files known by their id
		if (isFile('$SRC/preload/data/characters/$key.json') && !doneChars.exists(key)) pendingChars.push(key);
		for (folder in ['dialogue/conversations', 'dialogue/boxes', 'dialogue/speakers', 'notestyles', 'ui/freeplay/albums', 'ui/freeplay/styles', 'stickerpacks'])
		{
			var path:String = 'data/$folder/$key.json';
			if (isFile('$SRC/preload/$path') && !copied.exists(path))
				if (add('preload', path, 'data') && copied.exists(path)) resolveJson('$SRC/preload/$path', group);
		}
	}

	static function walkStrings(value:Dynamic, out:Array<String>)
	{
		if (value == null) return;
		if (Std.isOfType(value, String)) out.push(value);
		else if (Std.isOfType(value, Array)) for (item in (value : Array<Dynamic>)) walkStrings(item, out);
		else if (isObject(value)) for (field in Reflect.fields(value)) walkStrings(Reflect.field(value, field), out);
	}

	static function resolveJson(path:String, group:String):Dynamic
	{
		var data:Dynamic = null;
		try
			data = Tools.readJson(path)
		catch (e:Dynamic)
		{
			Sys.println('  could not read $path $e');
			return null;
		}
		var strings:Array<String> = [];
		walkStrings(data, strings);
		for (s in strings) resolve(s, group);
		return data;
	}

	static function resolveScript(path:String, group:String)
	{
		var code:String = Tools.readText(path);
		code = ~/\/\*[\s\S]*?\*\//g.replace(code, '');
		code = ~/^\s*\/\/.*$/gm.replace(code, '');
		~/"((?:[^"\\\n]|\\.)*)"|'((?:[^'\\\n]|\\.)*)'/g.map(code, function(r:EReg) {
			var first:String = group1(r, 1);
			resolve(first != null ? first : group1(r, 2), group);
			return '';
		});
	}

	// ---------------------------------------------------------------------------------------------
	// Songs
	// ---------------------------------------------------------------------------------------------
	static function resolveVoices(char:String, suffix:String, exists:String->Bool):String
	{
		for (cur in (suffix != '' ? [suffix, ''] : ['']))
		{
			var cid:String = char;
			while (cid != '')
			{
				var name:String = 'Voices-$cid$cur';
				if (exists(name)) return name;
				cid = cid.contains('-') ? cid.substr(0, cid.lastIndexOf('-')) : '';
			}
		}
		return null;
	}

	static function songAudio(song:String, variation:String, characters:Dynamic):Array<String>
	{
		var folder:String = '$SRC/songs/$song';
		var exists = (name:String) -> isFile('$folder/$name.ogg');
		var suffix:String = variation == 'default' ? '' : '-$variation';
		var names:Array<String> = [];
		var inst:String = 'Inst';
		for (name in [truthy(characters.instrumental) ? 'Inst-' + characters.instrumental : null, 'Inst$suffix'])
			if (name != null && exists(name))
			{
				inst = name;
				break;
			}
		names.push(inst);
		var alts:Array<Dynamic> = characters.altInstrumentals;
		if (alts != null)
			for (alt in alts)
				if (truthy(alt) && exists('Inst-$alt')) names.push('Inst-$alt');
		var playerIds:Array<Dynamic> = truthyArray(characters.playerVocals) ? characters.playerVocals : [truthy(characters.player) ? characters.player : ''];
		var opponentIds:Array<Dynamic> = truthyArray(characters.opponentVocals) ? characters.opponentVocals : [truthy(characters.opponent) ? characters.opponent : ''];
		for (cid in playerIds.concat(opponentIds))
		{
			var found:String = resolveVoices(Std.string(cid), suffix, exists);
			if (found != null) names.push(found);
		}
		for (name in ['Voices$suffix', 'Voices'])
			if (exists(name))
			{
				names.push(name);
				break;
			}
		return names;
	}

	// ---------------------------------------------------------------------------------------------
	// Little helpers
	// ---------------------------------------------------------------------------------------------
	static function folderArg(path:String):String
	{
		var p:String = path.replace('\\', '/');
		while (p.endsWith('/')) p = p.substr(0, p.length - 1);
		return p;
	}

	// (a name the engine and V-Slice could write differently: only its letters and numbers)
	static function simple(name:String):String
		return ~/[^a-z0-9]/g.replace(name.toLowerCase(), '');

	// (paths made of texts from the files can have anything in them: one that can't be a file just isn't one)
	static function isFile(path:String):Bool
	{
		try
			return FileSystem.exists(path) && !FileSystem.isDirectory(path)
		catch (_:Dynamic)
			return false;
	}

	static function isDir(path:String):Bool
	{
		try
			return FileSystem.exists(path) && FileSystem.isDirectory(path)
		catch (_:Dynamic)
			return false;
	}

	static function makeFolders(file:String)
	{
		var dir:String = file.substr(0, file.lastIndexOf('/'));
		if (!isDir(dir)) FileSystem.createDirectory(dir);
	}

	static function walkFiles(root:String):Array<String>
	{
		var out:Array<String> = [];
		function go(rel:String)
		{
			var dir:String = rel == '' ? root : '$root/$rel';
			var files:Array<String> = [];
			var folders:Array<String> = [];
			for (name in FileSystem.readDirectory(dir))
				(isDir('$dir/$name') ? folders : files).push(name);
			for (f in files) out.push(rel == '' ? f : '$rel/$f');
			for (d in folders) go(rel == '' ? d : '$rel/$d');
		}
		go('');
		return out;
	}

	static function sorted(list:Array<String>):Array<String>
	{
		var copy:Array<String> = list.copy();
		copy.sort(Tools.compare);
		return copy;
	}

	static function findAll(re:EReg, text:String):Array<String>
	{
		var out:Array<String> = [];
		re.map(text, function(r:EReg) {
			out.push(r.matched(1));
			return r.matched(0);
		});
		return out;
	}

	static function group1(r:EReg, n:Int):String
	{
		try
			return r.matched(n)
		catch (_:Dynamic)
			return null;
	}

	// (every sign gets a "\\" before it: the name is matched as it is)
	static function escapeRegex(text:String):String
	{
		var out:StringBuf = new StringBuf();
		for (i in 0...text.length)
		{
			var c:String = text.charAt(i);
			var code:Int = text.charCodeAt(i);
			var plain:Bool = (code >= '0'.code && code <= '9'.code) || (code >= 'a'.code && code <= 'z'.code) || (code >= 'A'.code && code <= 'Z'.code) || code > 127;
			if (!plain) out.add('\\');
			out.add(c);
		}
		return out.toString();
	}

	static function stripSlashes(text:String):String
	{
		var start:Int = 0;
		var end:Int = text.length;
		while (start < end && text.charAt(start) == '/') start++;
		while (end > start && text.charAt(end - 1) == '/') end--;
		return text.substring(start, end);
	}

	static function lastSlash(path:String):Int
		return Std.int(Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\')));

	static function dirName(path:String):String
		return lastSlash(path) < 0 ? '' : path.substr(0, lastSlash(path));

	static function baseName(path:String):String
		return path.substr(lastSlash(path) + 1);

	// ".png" for "a/b.png", "" for "a/b" or "a/.hidden"
	static function extension(path:String):String
	{
		var name:String = baseName(path);
		var dot:Int = name.lastIndexOf('.');
		var start:Int = 0;
		while (start < name.length && name.charAt(start) == '.') start++;
		return dot > start - 1 && dot >= start ? name.substr(dot) : '';
	}

	// "a/./b/../c" -> "a/c"
	static function normalize(path:String):String
	{
		var parts:Array<String> = [];
		for (part in path.replace('\\', '/').split('/'))
		{
			if (part == '' || part == '.') continue;
			if (part == '..' && parts.length > 0 && parts[parts.length - 1] != '..') parts.pop();
			else parts.push(part);
		}
		return parts.join('/');
	}

	static function isObject(value:Dynamic):Bool
		return value != null && Reflect.isObject(value) && !Std.isOfType(value, String) && !Std.isOfType(value, Array);

	// (what Python counts as true: not null, not "", not 0, not false)
	static function truthy(value:Dynamic):Bool
		return value != null && value != '' && value != false && value != 0;

	static function truthyArray(value:Dynamic):Bool
		return value != null && Std.isOfType(value, Array) && (value : Array<Dynamic>).length > 0;

	// ['a', 'b'], the way Python prints a list
	static function pyList(list:Array<String>):String
		return '[' + [for (s in list) "'" + s + "'"].join(', ') + ']';
}

typedef ScriptInfo =
{
	var declared:Array<String>;
	var extended:Array<String>;
	var ids:Array<String>;
	var variation:String;
}
