package funkin.save;

/**
 * The part of V-Slice's save file scripts use, kept on the engine's own save.
 */
class Save
{
	public static var instance(get, never):Save;
	static var _instance:Save = null;
	static function get_instance():Save
	{
		if(_instance == null) _instance = new Save();
		return _instance;
	}

	/**
	 * Where mods keep their own options, they stay saved between sessions.
	 */
	public var modOptions(get, never):Map<String, Dynamic>;
	var _modOptions:Map<String, Dynamic> = null;
	function get_modOptions():Map<String, Dynamic>
	{
		if(_modOptions == null)
		{
			_modOptions = new Map<String, Dynamic>();
			watchExit();

			// saved as a structure, which survives whatever the save file goes through
			var saved:Dynamic = FlxG.save.data.vsliceModOptions;
			if(saved != null)
				for (field in Reflect.fields(saved))
					_modOptions.set(field, Reflect.field(saved, field));
		}
		return _modOptions;
	}

	function new() {}

	public function flush():Void
	{
		keepModOptions();
		FlxG.save.flush();
	}

	/**
	 * Puts the mods' options in the engine's save, for its next flush. On V-Slice they're part of the save, and every time it's
	 * written they go with it: mods change them and never save them themselves. Here they go whenever the engine saves its
	 * settings, and when the game closes.
	 */
	public static function keepModOptions():Void
	{
		if(_instance == null || _instance._modOptions == null) return;

		var saved:Dynamic = {};
		for (key => value in _instance._modOptions)
			Reflect.setField(saved, key, value);
		FlxG.save.data.vsliceModOptions = saved;
	}

	static var watchingExit:Bool = false;

	// (once, when the options are first read: written to the save when the game closes)
	static function watchExit():Void
	{
		if(watchingExit || lime.app.Application.current == null) return;
		watchingExit = true;
		lime.app.Application.current.onExit.add(function(_)
		{
			if(_instance == null || _instance._modOptions == null) return;
			keepModOptions();
			FlxG.save.flush();
		});
	}

	public function getModOptions(modId:String):Dynamic
	{
		var options:Dynamic = modOptions.get(modId);
		if(options == null)
		{
			options = {};
			modOptions.set(modId, options);
		}
		return options;
	}

	public function setModOptions(modId:String, options:Dynamic):Void
	{
		modOptions.set(modId, options);
		flush();
	}

	/**
	 * If a week was finished. V-Slice's levels are Psych's weeks here, with the same name.
	 */
	public function hasBeatenLevel(levelId:String, ?difficultyList:Array<String>):Bool
	{
		return states.StoryMenuState.weekCompleted.get(levelId) == true;
	}

	public function hasBeatenSong(songId:String, ?difficultyList:Array<String>, ?variation:String):Bool
	{
		var key:String = Paths.formatToSongPath(songId);
		for (name => score in backend.Highscore.songScores)
			if(score > 0 && (name == key || name.startsWith('$key-')))
				return true;
		return false;
	}

	public function getSongScore(songId:String, difficultyId:String = 'normal', ?variation:String):Dynamic return null;
	public function getLevelScore(levelId:String, difficultyId:String = 'normal'):Dynamic return null;
	public function isSongFavorited(id:String):Bool return false;
	public function isCharacterUnlocked(characterId:String):Bool return true;
}
