package objects.freeplay;

import backend.FreeplayData;
import backend.PlayableCharacters;
import backend.VSliceConvert;
import backend.WeekData;

/**
 * A song of the V-Slice Freeplay menu and what the menu shows about it.
 *
 * Songs come from the week files like on the regular Freeplay, and each one belongs to the player that owns the character it's played with:
 * - Songs from V-Slice mods can have charts for more than one player ("song-chart-pico.json"), only the ones for the picked player are used.
 * - On Psych songs it's the "player1" of the chart: a song played with "pico-playable" only shows up for Pico.
 * Characters that belong to nobody are for the players with "showUnownedChars", which is only Boyfriend on the base game.
 */
class FreeplaySong
{
	public var name:String; //Name on the week file, what the song is loaded and saved by
	public var week:Int; //Position on WeekData.weeksList
	public var folder:String; //Mod folder
	public var icon:String; //Health icon on the week file
	public var levelName:String;
	public var difficulties:Array<String>; //Difficulties of its week, with the names the week gives them
	public var favoriteKey:String;

	// What's shown, depends on the difficulty the menu is on
	public var displayName:String;
	public var opponent:String; //Character whose pixel icon is used
	public var bpm:Float = 0;
	public var rating:Int = 0; //Stars
	public var album:String = null;
	public var previewStart:Float = 0; //Milliseconds

	#if MODS_ALLOWED
	public var vslice:VSliceSong = null; //Only on songs from V-Slice mods
	public var variation:VSliceVariation = null;
	#end

	var difficultyIds:Array<String>;
	var chartBpm:Float = 0;
	var info:Dynamic = null;

	// Names V-Slice scripts read from a song of the menu

	public var fullSongName(get, never):String;
	function get_fullSongName():String return displayName;

	public var isFav(get, never):Bool;
	function get_isFav():Bool return backend.FreeplayData.isFavorite(favoriteKey);

	/**
	 * Id of the week ("level") the song is from: the name of its week file.
	 */
	public var levelId(get, never):String;
	function get_levelId():String
	{
		var file:String = backend.WeekData.weeksList[week];
		if(file == null) return '';
		return file.substr(file.lastIndexOf('/') + 1);
	}

	public var songDifficulties(get, never):Array<String>;
	function get_songDifficulties():Array<String> return difficultyIds.copy();

	public var data(get, never):Dynamic;
	function get_data():Dynamic
	{
		var id:String = Paths.formatToSongPath(name);
		return {id: id, songName: displayName};
	}

	/**
	 * Makes a song of a week, the week's mod has to be the current one.
	 * Returns null if the song isn't for the given player.
	 */
	public static function make(name:String, icon:String, weekIndex:Int, weekData:WeekData, player:PlayableCharacter):FreeplaySong
	{
		var song:FreeplaySong = new FreeplaySong();
		song.name = name;
		song.displayName = name;
		song.icon = (icon != null && icon.length > 0) ? icon : 'face';
		song.opponent = song.icon;
		song.week = weekIndex;
		song.folder = (weekData.folder != null) ? weekData.folder : '';
		song.levelName = formatLevelName((weekData.weekName != null) ? weekData.weekName : '');

		Difficulty.loadFromWeek(weekData);
		song.difficulties = Difficulty.list.copy();
		song.difficultyIds = [for (diff in song.difficulties) Paths.formatToSongPath(diff)];

		var key:String = Paths.formatToSongPath(name);
		song.favoriteKey = song.folder + ':' + key;

		#if MODS_ALLOWED
		// The weeks of V-Slice mods are made for the picked player already, songs with nothing for it aren't even there
		song.vslice = PolymodCompat.getSong(song.folder, name);
		if(song.vslice != null) return song;
		#end

		// Psych song, any of its charts tells who plays it
		var defaultId:String = Paths.formatToSongPath(Difficulty.getDefault());
		var files:Array<String> = [key];
		for (diff in song.difficultyIds)
			if(diff != defaultId)
				files.push('$key-$diff');

		var chart:ChartInfo = null;
		for (file in files)
		{
			chart = FreeplayData.getChartInfo(Paths.json('$key/$file'));
			if(chart != null) break;
		}

		var chartPlayer:String = (chart != null && chart.player != null && chart.player.length > 0) ? chart.player : PlayableCharacters.DEFAULT;
		if(!PlayableCharacters.shouldShowCharacter(player, chartPlayer)) return null;

		if(chart != null) song.chartBpm = chart.bpm;
		song.info = FreeplayData.getSongInfo(song.folder, name);
		return song;
	}

	function new() {}

	// "bonusWeek2" -> "bonus Week 2", names that already have spaces are left alone
	static function formatLevelName(name:String):String
	{
		name = name.trim();
		if(name.contains(' ')) return name;

		var clean:String = '';
		for (i in 0...name.length)
		{
			var char:String = name.charAt(i);
			if(i > 0)
			{
				var last:String = name.charAt(i - 1);
				var lastIsNumber:Bool = (Std.parseInt(last) != null);
				var isNumber:Bool = (Std.parseInt(char) != null);

				if(last.toLowerCase() == last && !lastIsNumber && char.toLowerCase() != char) clean += ' ';
				else if(lastIsNumber != isNumber) clean += ' ';
			}
			clean += char;
		}
		return clean;
	}

	public function hasDifficulty(id:String):Bool
	{
		return difficultyIds.contains(id);
	}

	/**
	 * Position of a difficulty on the song's own list (what `PlayState.storyDifficulty` has to be), -1 if it doesn't have it.
	 */
	public function getDifficultyIndex(id:String):Int
	{
		return difficultyIds.indexOf(id);
	}

	public function getDifficultyIds():Array<String>
	{
		return difficultyIds;
	}

	/**
	 * Name the song's week gives to a difficulty, the same id if the song doesn't have it.
	 */
	public function getDifficultyName(id:String):String
	{
		var index:Int = difficultyIds.indexOf(id);
		return (index > -1) ? difficulties[index] : id;
	}

	/**
	 * Updates what the song shows for a difficulty.
	 */
	public function refresh(difficulty:String):Void
	{
		#if MODS_ALLOWED
		if(vslice != null)
		{
			// The first of the player's variations that has the difficulty, which is also the one that gets loaded
			var rawDifficulty:String = null;
			var found:VSliceVariation = null;
			for (curVariation in PolymodCompat.getPlayableVariations(vslice))
			{
				for (diff in curVariation.difficulties)
				{
					if(Paths.formatToSongPath(diff) != difficulty) continue;

					found = curVariation;
					rawDifficulty = diff;
					break;
				}
				if(found != null) break;
			}
			if(found == null && variation == null) found = vslice.variations[0];
			if(found != null) variation = found;

			var metadata:Dynamic = variation.metadata;
			var playData:Dynamic = metadata.playData;

			displayName = VSliceConvert.str(metadata.songName, name);
			album = VSliceConvert.str(playData.album, null);
			previewStart = VSliceConvert.num(playData.previewStart, 0);
			if(playData.characters != null) opponent = VSliceConvert.str(playData.characters.opponent, icon);

			var timeChanges:Array<Dynamic> = VSliceConvert.list(metadata.timeChanges);
			bpm = (timeChanges.length > 0) ? VSliceConvert.num(timeChanges[0].bpm, 0) : 0;

			rating = 0;
			if(playData.ratings != null && rawDifficulty != null) rating = Std.int(VSliceConvert.num(Reflect.field(playData.ratings, rawDifficulty), 0));
			return;
		}
		#end

		bpm = chartBpm;
		rating = 0;
		album = null;
		if(info != null)
		{
			album = VSliceConvert.str(info.album, null);
			if(info.ratings != null) rating = Std.int(VSliceConvert.num(Reflect.field(info.ratings, difficulty), 0));
		}
	}

	/**
	 * If the song's script says it's new (V-Slice's `Song.isSongNew()`, "NEW" on its capsule). Only V-Slice songs have one.
	 */
	public function isNew(difficulty:String):Bool
	{
		#if HSCRIPT_ALLOWED
		if(vslice != null) return backend.VSliceScripts.isSongNew(vslice.id, difficulty, (variation != null) ? variation.id : 'default');
		#end
		return false;
	}

	public function isFavorite():Bool
	{
		return FreeplayData.isFavorite(favoriteKey);
	}

	/**
	 * The name the scores of a difficulty are kept under: each mix of a V-Slice song has its own, see `Highscore.scoreName()`.
	 */
	public function getScoreName(difficulty:String):String
	{
		#if MODS_ALLOWED
		if(vslice != null)
		{
			for (curVariation in PolymodCompat.getPlayableVariations(vslice))
				for (diff in curVariation.difficulties)
					if(Paths.formatToSongPath(diff) == difficulty)
						return backend.Highscore.scoreName(name, curVariation.id);
		}
		#end
		return name;
	}

	public function getScore(difficulty:String):Int
	{
		return FreeplayData.getScore(getScoreName(difficulty), difficulty);
	}

	public function getRating(difficulty:String):Float
	{
		return FreeplayData.getRating(getScoreName(difficulty), difficulty);
	}

	public function getRank(difficulty:String):Null<FreeplayRank>
	{
		return FreeplayData.getRank(getScoreName(difficulty), difficulty);
	}

	public function getClear(difficulty:String):Float
	{
		return FreeplayData.getClear(getScoreName(difficulty), difficulty);
	}
}
