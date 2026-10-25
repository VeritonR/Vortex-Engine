package funkin.data.story.level;

import funkin.ui.story.Level;

/**
 * Where V-Slice scripts ask about the weeks ("levels"): `LevelRegistry.instance.fetchEntry('week1').getSongs()`.
 * They're read from the level files of the mod being played.
 */
class LevelRegistry
{
	public static var instance:LevelRegistry = new LevelRegistry();

	public function new() {}

	static function findFile(id:String):String
	{
		#if MODS_ALLOWED
		var mod:String = backend.Mods.currentModDirectory;
		if(backend.PolymodCompat.isPolymod(mod)) return backend.PolymodCompat.findFile(mod, 'data/levels/$id.json');
		#end
		return null;
	}

	public function hasEntry(id:String):Bool
	{
		return findFile(id) != null;
	}

	public function fetchEntry(id:String, ?params:Dynamic):Level
	{
		var path:String = findFile(id);
		if(path == null) return null;

		var level:Level = new Level(id);
		#if sys
		try
		{
			level._data = haxe.Json.parse(#if MODS_ALLOWED backend.PolymodMerge.applyToPath(path, sys.io.File.getContent(path)) #else sys.io.File.getContent(path) #end);
		}
		catch(e:Dynamic) {}
		#end
		return level;
	}

	public function listEntryIds():Array<String>
	{
		var ids:Array<String> = [];
		#if MODS_ALLOWED
		var mod:String = backend.Mods.currentModDirectory;
		if(!backend.PolymodCompat.isPolymod(mod)) return ids;

		var folder:String = backend.Paths.mods('$mod/data/levels');
		if(sys.FileSystem.exists(folder) && sys.FileSystem.isDirectory(folder))
			for (file in sys.FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
					ids.push(file.substr(0, file.length - 5));
		ids.sort(Reflect.compare);
		#end
		return ids;
	}

	public function listBaseGameEntryIds():Array<String> return [];
	public function listModdedEntryIds():Array<String> return listEntryIds();
	public function listSortedLevelIds():Array<String> return listEntryIds();
}
