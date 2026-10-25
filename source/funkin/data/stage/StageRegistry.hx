package funkin.data.stage;

import funkin.play.stage.Stage;

/**
 * Where V-Slice scripts get stages from (`StageRegistry.instance.fetchEntry('mainStage')`): a stage of the song's mod or of the
 * base game, with its script if it has one. Scripts that change the stage in the middle of a song put it in the place of the
 * current one and build it (see `Stage.buildStage()`).
 */
class StageRegistry
{
	public static var instance(get, never):StageRegistry;
	static var _instance:StageRegistry = null;
	static function get_instance():StageRegistry
	{
		if(_instance == null) _instance = new StageRegistry();
		return _instance;
	}

	function new() {}

	/**
	 * A stage, not built yet. Null if there's no such stage.
	 */
	public function fetchEntry(id:String, ?params:Dynamic):Stage
	{
		if(id == null || id.length < 1) return null;

		#if HSCRIPT_ALLOWED
		var scripted:Stage = backend.VSliceScripts.makeStageScript(id);
		if(scripted != null) return scripted;
		#end

		return hasEntry(id) ? new Stage(id) : null;
	}

	public function hasEntry(id:String):Bool
	{
		return findFile(id) != null;
	}

	public function listEntryIds():Array<String>
	{
		var ids:Array<String> = [];
		#if MODS_ALLOWED
		for (mod in [backend.Mods.currentModDirectory, backend.PolymodCompat.BASE_MOD])
		{
			if(mod == null || mod.length < 1) continue;
			var folder:String = backend.PolymodCompat.findFile(mod, 'data/stages');
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

	/**
	 * What a stage's file has, as it's written (`props`, `directory`, `cameraZoom`, `characters`...). Null if there's no such stage.
	 */
	public function parseEntryData(id:String):Dynamic
	{
		var path:String = findFile(id);
		if(path == null) return null;

		try
		{
			#if sys
			return haxe.Json.parse(sys.io.File.getContent(path));
			#else
			return null;
			#end
		}
		catch(e:Dynamic)
		{
			trace('The stage "$id" could not be read: $e');
			return null;
		}
	}

	public function parseEntryDataWithMigration(id:String, ?version:Dynamic):Dynamic return parseEntryData(id);
	public function parseEntryDataRaw(contents:String, ?fileName:String):Dynamic return haxe.Json.parse(contents);

	public function fetchEntryVersion(id:String):String
	{
		var data:Dynamic = parseEntryData(id);
		return (data != null && data.version != null) ? Std.string(data.version) : null;
	}

	function findFile(id:String):String
	{
		if(id == null) return null;
		#if MODS_ALLOWED
		for (mod in [backend.Mods.currentModDirectory, backend.PolymodCompat.BASE_MOD])
		{
			if(mod == null || mod.length < 1) continue;
			var path:String = backend.PolymodCompat.findFile(mod, 'data/stages/$id.json');
			if(path != null) return path;
		}
		#end
		return null;
	}
}
