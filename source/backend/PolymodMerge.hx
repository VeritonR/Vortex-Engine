package backend;

#if MODS_ALLOWED
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/**
 * The "_append" and "_merge" folders of V-Slice (Polymod) mods: files that change a data file of the game or of another mod
 * instead of replacing it. They're placed like the file they change: "_merge/data/players/bf.json" is for "data/players/bf.json".
 *
 * - "_append": text files get the new lines at their end, JSON files get the new values (see `JsonPatch.append()`).
 * - "_merge": for JSON files, a list of changes to make (see `JsonPatch.patch()`).
 *
 * It's how mods add their characters to an existing player ("ownedChars"), which is what makes their songs show up for that player.
 * The files of every V-Slice mod that's turned on are used, in the order of the mods.
 */
class PolymodMerge
{
	// What V-Slice keeps apart as "libraries", inside of those folders too
	static final libraryFolders:Array<String> = ['shared', 'preload', 'week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1', 'tutorial', 'sserafim'];

	// Folders of the mods folder itself that aren't mods
	static final contentFolders:Array<String> = ['data', 'images', 'sounds', 'music', 'songs', 'shaders', 'scripts', 'videos', 'fonts', 'characters', 'stages', 'weeks',
		'custom_events', 'custom_notetypes', 'achievements'];

	// File they change (in lowercase) -> the files, "_append" ones first for each mod
	static var index:Map<String, Array<{path:String, append:Bool}>> = null;

	/**
	 * To be called when the mods that are turned on could have changed.
	 */
	public static function clearCache():Void
	{
		index = null;
	}

	static function build():Void
	{
		// (only put in place once it's whole: the loading threads read files too)
		var found:Map<String, Array<{path:String, append:Bool}>> = [];
		for (mod in Mods.parseList().enabled)
		{
			if(!PolymodCompat.isPolymod(mod)) continue;

			scan(found, Paths.mods('$mod/_append'), '', true);
			scan(found, Paths.mods('$mod/_merge'), '', false);
		}
		index = found;
	}

	static function scan(index:Map<String, Array<{path:String, append:Bool}>>, folder:String, key:String, append:Bool):Void
	{
		if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;

		for (file in FileSystem.readDirectory(folder))
		{
			var path:String = '$folder/$file';
			if(FileSystem.isDirectory(path))
			{
				// libraries are just folders here, their files are found without them
				scan(index, path, (key.length < 1 && libraryFolders.contains(file.toLowerCase())) ? '' : key + file + '/', append);
				continue;
			}

			var target:String = (key + file).toLowerCase();
			if(!index.exists(target)) index.set(target, []);
			index.get(target).push({path: path, append: append});
		}
	}

	static function getIndex():Map<String, Array<{path:String, append:Bool}>>
	{
		var current:Map<String, Array<{path:String, append:Bool}>> = index;
		if(current != null) return current;

		build();
		return index;
	}

	/**
	 * What the files of a path are known by inside of those folders: "mods/My Mod/shared/data/thing.json" -> "data/thing.json".
	 */
	public static function getKey(path:String):String
	{
		if(path == null) return '';

		var key:String = path.replace('\\', '/');
		var modsRoot:String = Paths.mods().replace('\\', '/');
		if(key.startsWith(PolymodCompat.BASE_FOLDER + '/')) key = key.substr(PolymodCompat.BASE_FOLDER.length + 1); //the base game's own V-Slice content
		else if(key.startsWith(modsRoot))
		{
			key = key.substr(modsRoot.length);

			// the mod's folder, unless it's something of the mods folder itself
			var slash:Int = key.indexOf('/');
			if(slash > 0 && !contentFolders.contains(key.substr(0, slash).toLowerCase())) key = key.substr(slash + 1);
		}
		else if(key.startsWith('assets/')) key = key.substr('assets/'.length);

		var slash:Int = key.indexOf('/');
		if(slash > 0 && libraryFolders.contains(key.substr(0, slash).toLowerCase())) key = key.substr(slash + 1);
		return key;
	}

	/**
	 * If any mod has something to add to a file ("data/players/bf.json").
	 */
	public static function has(key:String):Bool
	{
		return key != null && getIndex().exists(key.toLowerCase());
	}

	/**
	 * The text of a file with what the mods add to it. It's given back as it is when there's nothing to add, which is almost always.
	 *
	 * @param key 	The file inside of the game's folders: "data/players/bf.json".
	 */
	public static function apply(key:String, text:String):String
	{
		if(text == null || key == null) return text;

		var files:Array<{path:String, append:Bool}> = getIndex().get(key.toLowerCase());
		if(files == null) return text;

		return key.toLowerCase().endsWith('.json') ? applyJson(key, text, files) : applyText(text, files);
	}

	/**
	 * The same for a file whose path is all that's known.
	 */
	public static function applyToPath(path:String, text:String):String
	{
		if(text == null || path == null) return text;
		if(!getIndex().keys().hasNext()) return text;

		return apply(getKey(path), text);
	}

	/**
	 * The lines the mods add to a text file, for what reads those a line at a time.
	 */
	public static function getAppendedLines(key:String):Array<String>
	{
		var lines:Array<String> = [];
		if(key == null) return lines;

		var files:Array<{path:String, append:Bool}> = getIndex().get(key.toLowerCase());
		if(files == null) return lines;

		for (file in files)
		{
			if(!file.append) continue;

			try
			{
				for (line in read(file.path).split('
'))
				{
					line = line.trim();
					if(line.length > 0) lines.push(line);
				}
			}
			catch(e:Dynamic)
			{
				trace('Could not read "${file.path}": $e');
			}
		}
		return lines;
	}

	static function applyText(text:String, files:Array<{path:String, append:Bool}>):String
	{
		for (file in files)
		{
			if(!file.append) continue;

			try
			{
				var extra:String = read(file.path);
				if(text.length > 0 && !text.endsWith('\n')) text += '\n';
				text += extra;
			}
			catch(e:Dynamic)
			{
				trace('Could not read "${file.path}": $e');
			}
		}
		return text;
	}

	static function applyJson(key:String, text:String, files:Array<{path:String, append:Bool}>):String
	{
		var data:Dynamic = null;
		try
		{
			data = parse(text);
		}
		catch(e:Dynamic)
		{
			trace('The file "$key" could not be read to have the changes of the mods made to it: $e');
			return text;
		}

		for (file in files)
		{
			try
			{
				var extra:Dynamic = parse(read(file.path));
				data = file.append ? JsonPatch.append(data, extra) : JsonPatch.patch(data, extra, file.path);
			}
			catch(e:Dynamic)
			{
				trace('Could not read "${file.path}": $e');
			}
		}
		return Json.stringify(data);
	}

	static function read(path:String):String
	{
		var raw:String = File.getContent(path);
		return (raw.fastCodeAt(0) == 0xFEFF) ? raw.substr(1) : raw; //UTF-8 BOM
	}

	static function parse(raw:String):Dynamic
	{
		if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1);
		try
		{
			return Json.parse(raw);
		}
		catch(e:Dynamic)
		{
			return tjson.TJSON.parse(raw); //more forgiving with hand written files
		}
	}
}
#end
