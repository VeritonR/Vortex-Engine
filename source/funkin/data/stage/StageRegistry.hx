package funkin.data.stage;

import funkin.play.stage.Stage;

/**
 * Where V-Slice scripts get stages from (`StageRegistry.instance.fetchEntry('mainStage')`): a stage of the song's mod or of the
 * base game, with its script if it has one. Scripts that change the stage in the middle of a song put it in the place of the
 * current one and build it (see `Stage.buildStage()`).
 */
class StageRegistry
{
	// (the version of V-Slice's stage files it reads)
	public static final STAGE_DATA_VERSION:String = '1.0.2';
	public static final STAGE_DATA_VERSION_RULE:String = '>=1.0.0 <1.1.0';

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
	/*
	 * Like V-Slice's registry, asking for a stage again gives the same one: the one the song is on when it's that one (IndieCross
	 * asks for "hall" on every frame to read what its script made), or the one made the last time. A new one was made every time,
	 * a script of each stage made until finding it on every frame, and it had nothing of what the stage on the screen had.
	 * They go with the song.
	 */
	var entries:Map<String, Stage> = [];
	var entriesOf:Dynamic = null;

	public function fetchEntry(id:String, ?params:Dynamic):Stage
	{
		if(id == null || id.length < 1) return null;

		var playing:funkin.play.PlayState = funkin.play.PlayState.instance;
		if(playing != null && playing.currentStage != null && playing.currentStage.id == id && playing.currentStage.alive)
			return playing.currentStage;

		if(entriesOf != states.PlayState.instance)
		{
			entries = [];
			entriesOf = states.PlayState.instance;
		}
		var kept:Stage = entries.get(id);
		if(kept != null && kept.alive) return kept;

		var stage:Stage = null;
		#if HSCRIPT_ALLOWED
		stage = backend.VSliceScripts.makeStageScript(id);
		#end
		if(stage == null && hasEntry(id)) stage = new Stage(id);
		if(stage != null) entries.set(id, stage);
		return stage;
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
