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

	/**
	 * The best score of a song on a difficulty, null if it was never played: `{score, tallies, accuracy}`. The engine keeps
	 * the score and the accuracy, not how many of each rating the play had (the tallies are all 0).
	 */
	public function getSongScore(songId:String, difficultyId:String = 'normal', ?variation:String):Dynamic
	{
		var key:String = backend.FreeplayData.getScoreKey(backend.Highscore.scoreName(songId, variation), difficultyId);
		if(!backend.Highscore.songScores.exists(key) || backend.Highscore.songScores.get(key) <= 0) return null;

		var accuracy:Float = backend.Highscore.songRating.exists(key) ? backend.Highscore.songRating.get(key) : 0;
		return {score: backend.Highscore.songScores.get(key), tallies: emptyTallies(), accuracy: accuracy};
	}

	/**
	 * The best score of a week on a difficulty, null if it was never finished (see getSongScore()).
	 */
	public function getLevelScore(levelId:String, difficultyId:String = 'normal'):Dynamic
	{
		var key:String = backend.FreeplayData.getScoreKey(levelId, difficultyId);
		if(!backend.Highscore.weekScores.exists(key) || backend.Highscore.weekScores.get(key) <= 0) return null;
		return {score: backend.Highscore.weekScores.get(key), tallies: emptyTallies()};
	}

	static function emptyTallies():Dynamic
		return {sick: 0, good: 0, bad: 0, shit: 0, missed: 0, combo: 0, maxCombo: 0, totalNotesHit: 0, totalNotes: 0};

	/**
	 * If a song is one of Freeplay's favorites, on any of the mods that have it.
	 */
	public function isSongFavorited(id:String):Bool
	{
		var name:String = ':' + Paths.formatToSongPath(id);
		var favorites:Array<String> = FlxG.save.data.freeplayFavorites;
		if(favorites != null)
			for (key in favorites)
				if(key != null && (key.endsWith(name) || key.indexOf(name + '-') > -1)) return true;
		return false;
	}

	/**
	 * If a player can be picked on Character Select.
	 */
	public function isCharacterUnlocked(characterId:String):Bool
	{
		var player:backend.PlayableCharacters.PlayableCharacter = backend.PlayableCharacters.get(characterId);
		return player == null || player.unlocked;
	}

	/**
	 * The players Character Select has shown already (the new ones get a spotlight there): `charactersSeen.value`.
	 */
	public var charactersSeen(get, never):Dynamic;
	function get_charactersSeen():Dynamic return {value: seenCharacters()};

	public function addCharacterSeen(character:String):Void
	{
		var seen:Array<String> = seenCharacters();
		if(seen.contains(character)) return;
		seen.push(character);
		FlxG.save.flush();
	}

	function seenCharacters():Array<String>
	{
		var seen:Array<String> = FlxG.save.data.vsliceCharactersSeen;
		if(seen == null) FlxG.save.data.vsliceCharactersSeen = seen = ['bf'];
		return seen;
	}
}
