package backend;

import backend.PlayableCharacters;

import haxe.Json;

typedef FreeplayStyle =
{
	var bgAsset:String;
	var selectorAsset:String;
	var numbersAsset:String;
	var capsuleAsset:String;
	var capsuleTextColors:Array<FlxColor>; //Glow of the song names: not selected, selected
	var startDelay:Float; //Seconds between picking a song and leaving the menu, the time the confirm animation takes
}

typedef FreeplayAlbum =
{
	var id:String;
	var artAsset:String;
	var titleAsset:String;
	var titleOffsets:Array<Float>;
	var ostName:String; //null to use the default one
}

typedef ChartInfo =
{
	var player:String; //null if the chart doesn't say
	var bpm:Float;
}

/**
 * Ranks shown on the songs of the V-Slice Freeplay menu, from worst to best.
 */
enum abstract FreeplayRank(Int) from Int to Int
{
	var LOSS = 0;
	var GOOD = 1;
	var GREAT = 2;
	var EXCELLENT = 3;
	var PERFECT = 4;
	var PERFECT_GOLD = 5;

	/**
	 * How much of a song was cleared, from 0 to 1: the notes hit with a Sick or a Good, minus the ones that were missed.
	 */
	public static function getCompletion(sick:Int, good:Int, missed:Int, totalNotes:Int):Float
	{
		if(totalNotes <= 0) return 0;
		return FlxMath.bound((sick + good - missed) / totalNotes, 0, 1);
	}

	/**
	 * The rank of a play, the way V-Slice works it out. Null if no notes were played at all.
	 */
	public static function fromTallies(sick:Int, good:Int, missed:Int, totalNotes:Int):Null<FreeplayRank>
	{
		if(totalNotes <= 0) return null;

		// nothing but Sicks
		if(sick == totalNotes) return PERFECT_GOLD;

		var completion:Float = getCompletion(sick, good, missed, totalNotes);
		if(completion >= 1) return PERFECT;
		if(completion >= 0.9) return EXCELLENT;
		if(completion >= 0.8) return GREAT;
		if(completion >= 0.6) return GOOD;
		return LOSS;
	}

	/**
	 * A rank out of Psych's accuracy, which was what the engine did before it kept the ranks themselves. Not V-Slice's rule.
	 */
	public static function fromRating(score:Int, rating:Float):Null<FreeplayRank>
	{
		if(score <= 0 && rating <= 0) return null; //never played

		if(rating >= 1) return PERFECT_GOLD;
		if(rating >= 0.95) return PERFECT;
		if(rating >= 0.9) return EXCELLENT;
		if(rating >= 0.8) return GREAT;
		if(rating >= 0.6) return GOOD;
		return LOSS;
	}

	// Name of the rank's animation on the "rankbadges" spritesheet
	public function getAnimation():String
	{
		return animations[this];
	}

	public function getColor():FlxColor
	{
		return colors[this];
	}

	static final animations:Array<String> = ['LOSS', 'GOOD', 'GREAT', 'EXCELLENT', 'PERFECT', 'PERFECTSICK'];
	static final colors:Array<FlxColor> = [0xFF6044FF, 0xFFEF8764, 0xFFEAF6FF, 0xFFFDCB42, 0xFFFF58B4, 0xFFFFB619];
}

/**
 * Data used by the V-Slice Freeplay menu that Psych doesn't have a place for.
 *
 * - `data/ui/freeplay/styles/(id).json` and `data/ui/freeplay/albums/(id).json`, same files as V-Slice.
 * - `data/ui/freeplay/songs.json`, album and star ratings of songs that aren't from a V-Slice mod (which have them on their own files):
 *   `{"song-name": {"album": "volume1", "ratings": {"easy": 1, "normal": 2, "hard": 3}}}`
 */
class FreeplayData
{
	static inline final DEFAULT_STYLE:String = 'bf';

	// ------------------------------------------------------------------------------------------
	// Styles and albums
	// ------------------------------------------------------------------------------------------

	/**
	 * Look of the menu for a player, always returns something usable.
	 */
	public static function getStyle(player:PlayableCharacter):FreeplayStyle
	{
		var style:FreeplayStyle = {
			bgAsset: 'freeplay/freeplayBGweek1-bf',
			selectorAsset: 'freeplay/freeplaySelector/freeplaySelector',
			numbersAsset: 'digital_numbers',
			capsuleAsset: 'freeplay/freeplayCapsule/capsule/freeplayCapsule',
			capsuleTextColors: [0xFF00CCFF, 0xFF00CCFF],
			startDelay: 1
		};

		var id:String = (player != null && player.freeplayStyle != null) ? player.freeplayStyle : DEFAULT_STYLE;
		var data:Dynamic = withMod((player != null) ? player.mod : null, () -> parse('data/ui/freeplay/styles/$id.json'));
		if(data == null) return style;

		style.bgAsset = asset(data.bgAsset, style.bgAsset);
		style.selectorAsset = asset(data.selectorAsset, style.selectorAsset);
		style.numbersAsset = asset(data.numbersAsset, style.numbersAsset);
		style.capsuleAsset = asset(data.capsuleAsset, style.capsuleAsset);
		style.startDelay = VSliceConvert.num(data.startDelay, style.startDelay);

		var colors:Array<Dynamic> = VSliceConvert.list(data.capsuleTextColors);
		for (i in 0...2)
		{
			if(colors[i] == null) continue;

			var color:Null<FlxColor> = FlxColor.fromString(Std.string(colors[i]));
			if(color != null) style.capsuleTextColors[i] = color;
		}
		return style;
	}

	/**
	 * Looks for the album on the current mod and on the base game, null if there's none with that id.
	 */
	public static function getAlbum(id:String):FreeplayAlbum
	{
		if(id == null || id.length < 1) return null;

		var data:Dynamic = parse('data/ui/freeplay/albums/$id.json');
		if(data == null) return null;

		var offsets:Array<Dynamic> = VSliceConvert.list(data.albumTitleOffsets);
		return {
			id: id,
			artAsset: asset(data.albumArtAsset, 'freeplay/albumRoll/volume1'),
			titleAsset: asset(data.albumTitleAsset, 'freeplay/albumRoll/volume1-text'),
			titleOffsets: [VSliceConvert.num(offsets[0], 0), VSliceConvert.num(offsets[1], 0)],
			ostName: VSliceConvert.str(data.albumOSTName, null)
		};
	}

	static var songInfo:Map<String, Dynamic> = [];

	/**
	 * Album and star ratings of a song from "data/ui/freeplay/songs.json", looking on the song's mod first. Null if it isn't listed anywhere.
	 */
	public static function getSongInfo(mod:String, song:String):Dynamic
	{
		var key:String = Paths.formatToSongPath(song);
		for (folder in [mod, ''])
		{
			if(folder == null) continue;

			if(!songInfo.exists(folder))
			{
				var path:String = (folder.length > 0) ? #if MODS_ALLOWED Paths.mods('$folder/data/ui/freeplay/songs.json') #else null #end : Paths.getSharedPath('data/ui/freeplay/songs.json');
				songInfo.set(folder, (path != null) ? parsePath(path) : null);
			}

			var data:Dynamic = songInfo.get(folder);
			if(data == null) continue;

			var info:Dynamic = Reflect.field(data, key);
			if(info != null) return info;
		}
		return null;
	}

	/**
	 * Forgets the files that were read, so changes made to them show up the next time the menu is opened.
	 */
	public static function clearCache():Void
	{
		songInfo = [];
	}

	// ------------------------------------------------------------------------------------------
	// Charts
	// ------------------------------------------------------------------------------------------

	static var chartCache:Map<String, {time:Float, info:ChartInfo}> = [];

	/**
	 * Who plays a Psych chart and its BPM, without loading the whole thing: the menu needs it from every song there is.
	 * Returns null if the file doesn't exist.
	 */
	public static function getChartInfo(path:String):ChartInfo
	{
		#if sys
		if(!FileSystem.exists(path)) return null;

		var time:Float = 0;
		try
		{
			time = FileSystem.stat(path).mtime.getTime();
		}
		catch(e:Dynamic) {}

		var cached = chartCache.get(path);
		if(cached != null && cached.time == time) return cached.info;

		var info:ChartInfo = null;
		try
		{
			info = scanChart(File.getContent(path));
		}
		catch(e:Dynamic)
		{
			trace('Could not read the chart "$path": $e');
			info = {player: null, bpm: 0};
		}
		chartCache.set(path, {time: time, info: info});
		return info;
		#else
		if(!openfl.utils.Assets.exists(path, TEXT)) return null;

		var cached = chartCache.get(path);
		if(cached != null) return cached.info;

		var info:ChartInfo = scanChart(openfl.utils.Assets.getText(path));
		chartCache.set(path, {time: 0, info: info});
		return info;
		#end
	}

	/**
	 * Reads "player1" and "bpm" straight from the text of a chart.
	 *
	 * Parsing every chart of every mod would take seconds, and the sections can have "bpm" values of their own,
	 * so only the values that belong to the song itself are looked at: the ones outside of any list.
	 */
	public static function scanChart(raw:String):ChartInfo
	{
		var info:ChartInfo = {player: null, bpm: 0};
		if(raw == null) return info;

		var foundBpm:Bool = false;
		var depth:Int = 0;
		var length:Int = raw.length;
		var i:Int = 0;
		while(i < length)
		{
			var code:Int = raw.fastCodeAt(i);
			if(code == '{'.code || code == '['.code) depth++;
			else if(code == '}'.code || code == ']'.code) depth--;
			else if(code == '"'.code)
			{
				// skips to the end of the text
				var start:Int = i + 1;
				i++;
				while(i < length)
				{
					var textCode:Int = raw.fastCodeAt(i);
					if(textCode == '\\'.code) i++;
					else if(textCode == '"'.code) break;
					i++;
				}

				// the song's values are on the first level of the file, or on the second one when it's wrapped by a "song" object
				var size:Int = i - start;
				if(depth >= 1 && depth <= 2 && (size == 3 || size == 7))
				{
					var name:String = raw.substring(start, i);
					if(name == 'bpm' || name == 'player1')
					{
						var valueStart:Int = skipSpaces(raw, i + 1);
						if(valueStart < length && raw.fastCodeAt(valueStart) == ':'.code)
						{
							valueStart = skipSpaces(raw, valueStart + 1);
							if(name == 'player1')
							{
								if(info.player == null && valueStart < length && raw.fastCodeAt(valueStart) == '"'.code)
								{
									var valueEnd:Int = raw.indexOf('"', valueStart + 1);
									if(valueEnd > valueStart)
									{
										info.player = raw.substring(valueStart + 1, valueEnd);
										i = valueEnd;
									}
								}
							}
							else if(!foundBpm)
							{
								var valueEnd:Int = valueStart;
								while(valueEnd < length && isNumberCode(raw.fastCodeAt(valueEnd))) valueEnd++;

								var value:Float = Std.parseFloat(raw.substring(valueStart, valueEnd));
								if(!Math.isNaN(value))
								{
									info.bpm = value;
									foundBpm = true;
								}
							}

							if(info.player != null && foundBpm) return info;
						}
					}
				}
			}
			i++;
		}
		return info;
	}

	static function skipSpaces(raw:String, position:Int):Int
	{
		var length:Int = raw.length;
		while(position < length)
		{
			var code:Int = raw.fastCodeAt(position);
			if(code != ' '.code && code != '\t'.code && code != '\n'.code && code != '\r'.code) break;
			position++;
		}
		return position;
	}

	inline static function isNumberCode(code:Int):Bool
	{
		return (code >= '0'.code && code <= '9'.code) || code == '.'.code || code == '-'.code || code == '+'.code || code == 'e'.code || code == 'E'.code;
	}

	// ------------------------------------------------------------------------------------------
	// Scores and favorites
	// ------------------------------------------------------------------------------------------

	/**
	 * Same name `Highscore.formatSong()` gives to a song's score, but from the difficulty's name instead of its position on the current list.
	 */
	public static function getScoreKey(song:String, difficulty:String):String
	{
		var postfix:String = Paths.formatToSongPath(difficulty);
		return Paths.formatToSongPath(song) + ((postfix == Paths.formatToSongPath(Difficulty.getDefault())) ? '' : '-$postfix');
	}

	// Reading these through Highscore would save the game for every song that was never played
	public static function getScore(song:String, difficulty:String):Int
	{
		var key:String = getScoreKey(song, difficulty);
		return Highscore.songScores.exists(key) ? Highscore.songScores.get(key) : 0;
	}

	public static function getRating(song:String, difficulty:String):Float
	{
		var key:String = getScoreKey(song, difficulty);
		return Highscore.songRating.exists(key) ? Highscore.songRating.get(key) : 0;
	}

	/**
	 * The best rank a song ever had, null if it was never ranked: ranks are kept when a song is played to the end,
	 * scores from before the engine did that don't have one.
	 */
	public static function getRank(song:String, difficulty:String):Null<FreeplayRank>
	{
		var key:String = getScoreKey(song, difficulty);
		if(!Highscore.songRanks.exists(key)) return null;

		var rank:Int = Highscore.songRanks.get(key);
		return (rank >= 0 && rank <= 5) ? rank : null; //from LOSS to PERFECT_GOLD
	}

	/**
	 * How much of a song was cleared from 0 to 1, on the play its rank is from. Songs without a rank use Psych's accuracy.
	 */
	public static function getClear(song:String, difficulty:String):Float
	{
		var key:String = getScoreKey(song, difficulty);
		if(Highscore.songClears.exists(key)) return FlxMath.bound(Highscore.songClears.get(key) / 100, 0, 1);
		return FlxMath.bound(getRating(song, difficulty), 0, 1);
	}

	static function getFavorites():Array<String>
	{
		var favorites:Array<String> = FlxG.save.data.freeplayFavorites;
		return (favorites != null) ? favorites : [];
	}

	public static function isFavorite(key:String):Bool
	{
		return getFavorites().contains(key);
	}

	/**
	 * Returns if the song is a favorite now.
	 */
	public static function toggleFavorite(key:String):Bool
	{
		var favorites:Array<String> = getFavorites();
		var isFavorite:Bool = !favorites.contains(key);
		if(isFavorite) favorites.push(key);
		else favorites.remove(key);

		FlxG.save.data.freeplayFavorites = favorites;
		FlxG.save.flush();
		return isFavorite;
	}

	// ------------------------------------------------------------------------------------------

	// Asset names can come with the library V-Slice loads them from ("shared:..."), which doesn't exist here
	inline static function asset(value:Dynamic, defaultValue:String):String
	{
		return VSliceConvert.stripLibrary(VSliceConvert.str(value, defaultValue));
	}

	/**
	 * Runs a function with the given mod as the current one, so its files are found first.
	 */
	public static function withMod<T>(mod:String, func:Void->T):T
	{
		var lastMod:String = Mods.currentModDirectory;
		if(mod != null && mod.length > 0) Mods.currentModDirectory = mod;

		var result:T = null;
		try
		{
			result = func();
		}
		catch(e:Dynamic)
		{
			trace('Freeplay: error loading something from the mod "$mod": $e');
		}
		Mods.currentModDirectory = lastMod;
		return result;
	}

	static function parse(key:String):Dynamic
	{
		var raw:String = Paths.getTextFromFile(key);
		return (raw != null) ? parseText(raw, key) : null;
	}

	static function parsePath(path:String):Dynamic
	{
		#if sys
		return FileSystem.exists(path) ? parseText(#if MODS_ALLOWED PolymodMerge.applyToPath(path, File.getContent(path)) #else File.getContent(path) #end, path) : null;
		#else
		return openfl.utils.Assets.exists(path, TEXT) ? parseText(openfl.utils.Assets.getText(path), path) : null;
		#end
	}

	static function parseText(raw:String, name:String):Dynamic
	{
		try
		{
			if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1); //UTF-8 BOM
			return Json.parse(raw);
		}
		catch(e:Dynamic)
		{
			trace('Could not read "$name": $e');
		}
		return null;
	}
}
