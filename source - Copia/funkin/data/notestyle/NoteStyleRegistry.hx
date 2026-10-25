package funkin.data.notestyle;

import funkin.play.notes.notestyle.NoteStyle;

/**
 * Where V-Slice scripts get note styles from (`NoteStyleRegistry.instance.fetchEntry('pixel')`): the files of the song's mod,
 * then the ones of the base game.
 */
class NoteStyleRegistry
{
	public static var instance(get, never):NoteStyleRegistry;
	static var _instance:NoteStyleRegistry = null;
	static function get_instance():NoteStyleRegistry
	{
		if(_instance == null) _instance = new NoteStyleRegistry();
		return _instance;
	}

	public static var DEFAULT_NOTE_STYLE_ID:String = 'funkin';

	function new() {}

	// The styles already read, by their id: the notes and the ratings ask theirs about it all the time. Read again for each song
	// (`clearCache()`) and for another mod
	var cache:Map<String, NoteStyle> = [];
	var baseCache:Map<String, NoteStyle> = [];
	var cachedMod:String = null;

	public function fetchEntry(id:String):NoteStyle
	{
		if(id == null || id.length < 1) return null;

		checkCache();
		if(cache.exists(id)) return cache.get(id);

		var data:Dynamic = readFile(id, false);
		var style:NoteStyle = (data != null) ? new NoteStyle(id, data) : null;
		cache.set(id, style);
		return style;
	}

	/**
	 * A note style as the base game has it, without what the mod being played changed of it (a mod can have a "funkin" of its own).
	 */
	public function fetchBaseEntry(id:String):NoteStyle
	{
		if(id == null || id.length < 1) return null;

		checkCache();
		if(baseCache.exists(id)) return baseCache.get(id);

		var data:Dynamic = readFile(id, true);
		var style:NoteStyle = (data != null) ? new NoteStyle(id, data) : null;
		baseCache.set(id, style);
		return style;
	}

	public function clearCache():Void
	{
		cache = [];
		baseCache = [];
	}

	function checkCache():Void
	{
		var mod:String = #if MODS_ALLOWED backend.Mods.currentModDirectory #else null #end;
		if(mod == cachedMod) return;
		cachedMod = mod;
		clearCache();
	}

	public function fetchDefault():NoteStyle
	{
		return fetchEntry(DEFAULT_NOTE_STYLE_ID);
	}

	public function hasEntry(id:String):Bool
	{
		return fetchEntry(id) != null;
	}

	public function listEntryIds():Array<String>
	{
		var ids:Array<String> = [];
		#if MODS_ALLOWED
		for (mod in [backend.Mods.currentModDirectory, backend.PolymodCompat.BASE_MOD])
		{
			if(mod == null || mod.length < 1) continue;
			var folder:String = backend.PolymodCompat.findFile(mod, 'data/notestyles');
			if(folder == null || !sys.FileSystem.isDirectory(folder)) continue;

			for (file in sys.FileSystem.readDirectory(folder))
			{
				if(!file.toLowerCase().endsWith('.json')) continue;
				var id:String = file.substr(0, file.length - 5);
				if(!ids.contains(id)) ids.push(id);
			}
		}
		#end
		return ids;
	}

	function readFile(id:String, baseOnly:Bool):Dynamic
	{
		var raw:String = null;
		#if MODS_ALLOWED
		for (mod in (baseOnly ? [backend.PolymodCompat.BASE_MOD] : [backend.Mods.currentModDirectory, backend.PolymodCompat.BASE_MOD]))
		{
			if(mod == null || mod.length < 1) continue;
			var path:String = backend.PolymodCompat.findFile(mod, 'data/notestyles/$id.json');
			if(path != null)
			{
				raw = sys.io.File.getContent(path);
				break;
			}
		}
		#end
		if(raw == null) return null;

		try
		{
			return haxe.Json.parse(raw);
		}
		catch(e:Dynamic)
		{
			trace('The note style "$id" could not be read: $e');
			return null;
		}
	}
}
