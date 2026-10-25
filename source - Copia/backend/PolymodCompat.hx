package backend;

#if MODS_ALLOWED
import haxe.Json;

import backend.PlayableCharacters;
import backend.Song;
import backend.StageData;
import backend.WeekData;

typedef VSliceVariation =
{
	var id:String; //"default", "erect", "pico"...
	var chartPath:String;
	var metadataPath:String;
	var metadata:Dynamic;
	var difficulties:Array<String>;
}

typedef VSliceSong =
{
	var id:String; //Name of the song's folder
	var name:String; //Name used by the menus, always turns into the folder name with Paths.formatToSongPath()
	var icon:String;
	var variations:Array<VSliceVariation>; //The default one is always the first
}

typedef PolymodWeek =
{
	var name:String;
	var file:WeekFile;
}

typedef PolymodData =
{
	var songs:Map<String, VSliceSong>; //Key is the formatted folder name
	var weeks:Array<PolymodWeek>;
}

/**
 * Lets mods made for V-Slice (Polymod) be used from Psych's own "mods" folder.
 *
 * A mod folder counts as a Polymod one when it has a "_polymod_meta.json" file.
 * The data needed to play its songs is read here: charts, audio, stages and characters,
 * everything gets converted to Psych's formats on load by `VSliceConvert`. Its scripts (.hxc) are run by `VSliceScripts`.
 */
class PolymodCompat
{
	public static inline final META_FILE:String = '_polymod_meta.json';

	/**
	 * What the base game has that Psych's format doesn't (the Erect remixes, the Pico and Boyfriend mixes, the LE SSERAFIM week)
	 * comes with the engine in V-Slice's own format, and is played by this same class. It isn't a mod: it's inside of the game's assets,
	 * it's always on and the mods menu doesn't list it. `BASE_MOD` is the name it goes by wherever a mod's folder name would be:
	 * `Mods.currentModDirectory`, the `folder` of its weeks... `Paths.mods()` leads from that name to where it really is.
	 */
	public static inline final BASE_MOD:String = 'base_game_vslice';
	public static inline final BASE_FOLDER:String = 'assets/vslice';

	// Id of that content on its own "_polymod_meta.json". A mod folder with the same id is a copy of it, and is left alone
	static inline final BASE_ID:String = 'funkin-vslice-base';

	/**
	 * Name to show for a mod folder: the base game's own content has no folder there.
	 */
	public static function getDisplayName(mod:String):String
	{
		return (mod == BASE_MOD) ? 'Base game (V-Slice content)' : mod;
	}
	public static inline final ICON_FILE:String = '_polymod_icon.png';

	// Polymod mods mirror the base game's asset libraries: what isn't on the mod's root is inside one of these
	// ("videos" is one too: a mod's videos are in "videos/videos", the folder of the library and then the one every video is asked from)
	static final libraryFolders:Array<String> = ['shared', 'week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1', 'tutorial', 'sserafim', 'videos'];
	static final defaultColor:Array<Int> = [146, 113, 253];

	// Mod folder -> library folders found inside of it.
	// Always replaced as a whole, so the loading threads can read it at any time
	static var mods:Map<String, Array<String>> = null;
	static var dataCache:Map<String, PolymodData> = [];

	/**
	 * Looks for the Polymod mods inside the mods folder again.
	 */
	public static function refresh():Void
	{
		var found:Map<String, Array<String>> = [];

		// the base game's own
		var basePath:String = BASE_FOLDER + '/';
		var hasBase:Bool = FileSystem.exists(basePath + META_FILE);
		if(hasBase) found.set(BASE_MOD, [for (library in libraryFolders) if(FileSystem.exists(basePath + library) && FileSystem.isDirectory(basePath + library)) library]);

		var modsFolder:String = Paths.mods();
		if(FileSystem.exists(modsFolder))
		{
			for (folder in FileSystem.readDirectory(modsFolder))
			{
				var path:String = modsFolder + folder + '/';
				if(!FileSystem.exists(path + META_FILE)) continue;

				// (a copy of the base game's content that was left on the mods folder would show every one of its songs twice)
				if(hasBase && readMetaId(path + META_FILE) == BASE_ID) continue;

				found.set(folder, [for (library in libraryFolders) if(FileSystem.exists(path + library) && FileSystem.isDirectory(path + library)) library]);
			}
		}
		mods = found;
		PolymodMerge.clearCache();
	}

	// The id a mod gives itself on its "_polymod_meta.json". It's read as it is, not with parseFile(): that one also looks for what
	// other mods add to the file (PolymodMerge), which needs the list of mods refresh() is still making and would start it all over, forever
	static function readMetaId(path:String):String
	{
		try
		{
			var raw:String = File.getContent(path);
			if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1); //UTF-8 BOM

			var meta:Dynamic = null;
			try
			{
				meta = Json.parse(raw);
			}
			catch(e:Dynamic)
			{
				meta = tjson.TJSON.parse(raw);
			}
			return (meta != null && meta.id != null) ? Std.string(meta.id) : null;
		}
		catch(e:Dynamic) {}
		return null;
	}

	/**
	 * Forgets the songs and weeks that were read, so changes made to the files show up without restarting.
	 */
	public static function clearCache():Void
	{
		dataCache = [];
		PolymodMerge.clearCache();
	}

	public static function isPolymod(mod:String):Bool
	{
		if(mods == null) refresh();
		return mod != null && mod.length > 0 && mods.exists(mod);
	}

	/**
	 * Looks for a file inside the mod's library folders, like "shared/images/characters/bf.png" for "images/characters/bf.png".
	 * Returns null if it's not there or if the mod isn't a Polymod one.
	 */
	public static function findInLibraries(mod:String, key:String):String
	{
		if(mods == null) refresh();

		var libraries:Array<String> = (mod != null) ? mods.get(mod) : null;
		if(libraries == null) return null;

		// The library of the stage being played comes first, like on V-Slice: more than one can have a file with the same name
		// ("erect/bg.png" is on the libraries of two weeks). There it's only that one and "shared", here the others are looked at too
		var level:String = Paths.currentLevel;
		var looked:String = null;
		if(level != null && libraries.contains(level))
		{
			var path:String = Paths.mods('$mod/$level/$key');
			if(FileSystem.exists(path)) return path;
			looked = level;
		}

		for (library in libraries)
		{
			if(library == looked) continue; //(only the one that was already looked at: a stage of "shared" used to leave "shared" out here)

			var path:String = Paths.mods('$mod/$library/$key');
			if(FileSystem.exists(path)) return path;
		}
		return null;
	}

	/**
	 * Looks for a file on the mod's root and then inside its libraries, returns null if it doesn't exist.
	 */
	public static function findFile(mod:String, key:String):String
	{
		var path:String = Paths.mods('$mod/$key');
		return FileSystem.exists(path) ? path : findInLibraries(mod, key);
	}

	/**
	 * Same data a "pack.json" would have, taken from the mod's metadata.
	 */
	public static function getPack(mod:String):Dynamic
	{
		if(!isPolymod(mod)) return null;

		var meta:Dynamic = parseFile(Paths.mods('$mod/$META_FILE'));
		if(meta == null) return null;

		var description:String = VSliceConvert.str(meta.description, '');
		var authors:Array<String> = [];
		for (contributor in VSliceConvert.list(meta.contributors))
		{
			var name:String = VSliceConvert.str(contributor.name, '');
			if(name.length > 0) authors.push(name);
		}

		if(authors.length > 0)
		{
			if(description.length > 0) description += '\n';
			description += 'By: ' + authors.join(', ');
		}

		return {
			name: VSliceConvert.str(meta.title, mod),
			description: description,
			restart: false,
			runsGlobally: false
		};
	}

	// ------------------------------------------------------------------------------------------
	// Weeks
	// ------------------------------------------------------------------------------------------

	/**
	 * Weeks made out of the mod's levels (Story Mode) and one for each of its songs (Freeplay),
	 * so every song can have its own list of difficulties.
	 */
	public static function getWeeks(mod:String):Array<PolymodWeek>
	{
		return isPolymod(mod) ? getData(mod).weeks : [];
	}

	static function getData(mod:String):PolymodData
	{
		var data:PolymodData = dataCache.get(mod);
		if(data != null) return data;

		data = {songs: [], weeks: []};
		dataCache.set(mod, data);

		// Songs
		var songOrder:Array<String> = [];
		var iconCache:Map<String, String> = [];

		var songsFolder:String = Paths.mods('$mod/data/songs/');
		if(FileSystem.exists(songsFolder) && FileSystem.isDirectory(songsFolder))
		{
			for (id in FileSystem.readDirectory(songsFolder))
			{
				var songFolder:String = songsFolder + id + '/';
				if(!FileSystem.isDirectory(songFolder)) continue;

				var variations:Array<VSliceVariation> = [];
				var prefix:String = '$id-metadata'.toLowerCase();
				for (file in FileSystem.readDirectory(songFolder))
				{
					var lowerFile:String = file.toLowerCase();
					if(!lowerFile.startsWith(prefix) || !lowerFile.endsWith('.json')) continue;

					// "song-metadata.json" is the default variation, "song-metadata-erect.json" the erect one
					var suffix:String = file.substring(prefix.length, file.length - '.json'.length);
					if(suffix.length > 0 && !suffix.startsWith('-')) continue;

					var chartPath:String = songFolder + '$id-chart$suffix.json';
					if(!FileSystem.exists(chartPath)) continue;

					var metadata:Dynamic = parseFile(songFolder + file);
					if(metadata == null || metadata.playData == null) continue;

					var difficulties:Array<String> = [for (diff in VSliceConvert.list(metadata.playData.difficulties)) Std.string(diff)];
					if(difficulties.length < 1) continue;

					var variation:VSliceVariation = {
						id: (suffix.length > 0) ? suffix.substr(1) : 'default',
						chartPath: chartPath,
						metadataPath: songFolder + file,
						metadata: metadata,
						difficulties: difficulties
					};

					if(suffix.length < 1) variations.unshift(variation);
					else variations.push(variation);
				}
				// Only the variations the song's own metadata lists ("songVariations") are part of it, like on V-Slice (`Song.new()`):
				// files of others in its folder are left out, they can be unfinished or meant for something else
				if(variations.length > 0 && variations[0].id == 'default')
				{
					var listed:Array<String> = [for (name in VSliceConvert.list(variations[0].metadata.playData.songVariations)) Std.string(name).toLowerCase()];
					variations = [for (variation in variations) if(variation.id == 'default' || listed.contains(variation.id.toLowerCase())) variation];
				}
				if(variations.length < 1) continue;

				var key:String = Paths.formatToSongPath(id);
				var metadata:Dynamic = variations[0].metadata;

				// the menus use the song's name to find its files, so it can only be shown if it leads to the folder
				var name:String = VSliceConvert.str(metadata.songName, id);
				if(Paths.formatToSongPath(name) != key) name = id;

				var opponent:String = 'face';
				if(metadata.playData.characters != null) opponent = VSliceConvert.str(metadata.playData.characters.opponent, 'face');
				if(!iconCache.exists(opponent)) iconCache.set(opponent, getCharacterIcon(mod, opponent));

				data.songs.set(key, {id: id, name: name, icon: iconCache.get(opponent), variations: variations});
				songOrder.push(key);
			}
		}

		// Levels, each one is a Story Mode week
		var songColors:Map<String, Array<Int>> = [];
		var songLevels:Map<String, String> = [];

		var levelsFolder:String = Paths.mods('$mod/data/levels/');
		if(FileSystem.exists(levelsFolder) && FileSystem.isDirectory(levelsFolder))
		{
			for (file in FileSystem.readDirectory(levelsFolder))
			{
				if(!file.toLowerCase().endsWith('.json')) continue;

				var level:Dynamic = parseFile(levelsFolder + file);
				if(level == null) continue;

				var color:Array<Int> = parseColor(VSliceConvert.str(level.background, ''));
				var levelId:String = file.substr(0, file.length - '.json'.length);

				var songs:Array<VSliceSong> = [];
				for (songId in VSliceConvert.list(level.songs))
				{
					var key:String = Paths.formatToSongPath(Std.string(songId));
					var song:VSliceSong = data.songs.get(key);
					if(song == null) continue; //base game songs or ones from other mods

					songs.push(song);
					if(!songColors.exists(key)) songColors.set(key, color);
					if(!songLevels.exists(key)) songLevels.set(key, levelId);
				}
				if(songs.length < 1) continue;

				// only the difficulties every song of the level has, like the base game does
				var difficulties:Array<String> = songs[0].variations[0].difficulties.copy();
				for (song in songs)
					difficulties = difficulties.filter((diff) -> song.variations[0].difficulties.contains(diff));
				if(difficulties.length < 1) difficulties = songs[0].variations[0].difficulties.copy();

				// Story Mode loads "storymenu/(week name)" as the week's image, which matches where V-Slice keeps the level titles
				var weekName:String = '$mod/levels/$levelId';
				var titleAsset:String = VSliceConvert.stripLibrary(VSliceConvert.str(level.titleAsset, ''));
				if(titleAsset.startsWith('storymenu/') && titleAsset.length > 'storymenu/'.length) weekName = titleAsset.substr('storymenu/'.length);

				var levelName:String = VSliceConvert.str(level.name, levelId);
				data.weeks.push({
					name: weekName,
					file: makeWeek([for (song in songs) ([song.name, song.icon, color] : Array<Dynamic>)], levelName, difficulties, true)
				});
			}
		}

		// Freeplay. On the V-Slice one each song gets the difficulties of the variations made for the player picked on Character Select,
		// and the songs with nothing for that player aren't there. The standard one has no Character Select: every song shows up on it,
		// with the difficulties of all of its variations (the picked character's chart is the one played when a difficulty has more than one)
		var everyVariation:Bool = (ClientPrefs.data.freeplayStyle != 'V-Slice');
		for (key in songOrder)
		{
			var song:VSliceSong = data.songs.get(key);

			var difficulties:Array<String> = [];
			for (variation in (everyVariation ? song.variations : getPlayableVariations(song)))
				for (diff in variation.difficulties)
					if(!difficulties.contains(diff))
						difficulties.push(diff);
			if(difficulties.length < 1) continue; //nothing for this player

			// the week's name is what the V-Slice Freeplay shows under the song: the level it's from
			var color:Array<Int> = songColors.exists(key) ? songColors.get(key) : defaultColor;
			var week:WeekFile = makeWeek([([song.name, song.icon, color] : Array<Dynamic>)], song.name, difficulties, false);
			if(songLevels.exists(key)) week.weekName = songLevels.get(key);
			data.weeks.push({name: '$mod/songs/${song.id}', file: week});
		}
		return data;
	}

	/**
	 * A song can have charts for different players ("song-chart-pico.json" for Pico), which are told apart by the character that plays them.
	 * Same rule as V-Slice: the ones played by a character of the picked player, plus the ones that belong to nobody if that player shows those.
	 */
	public static function getPlayableVariations(song:VSliceSong):Array<VSliceVariation>
	{
		var player:PlayableCharacter = PlayableCharacters.getCurrent();
		return song.variations.filter(function(variation:VSliceVariation)
		{
			var characters:Dynamic = variation.metadata.playData.characters;
			return PlayableCharacters.shouldShowCharacter(player, (characters != null) ? VSliceConvert.str(characters.player, 'bf') : 'bf');
		});
	}

	static function makeWeek(songs:Array<Dynamic>, name:String, difficulties:Array<String>, storyMode:Bool):WeekFile
	{
		return {
			songs: songs,
			weekCharacters: ['', '', ''],
			weekBackground: '',
			weekBefore: '',
			storyName: name,
			weekName: name,
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: !storyMode,
			hideFreeplay: storyMode,
			difficulties: [for (diff in VSliceConvert.sortDifficulties(difficulties)) VSliceConvert.difficultyDisplayName(diff)].join(', ')
		};
	}

	static function getCharacterIcon(mod:String, char:String):String
	{
		var path:String = findFile(mod, 'data/characters/$char.json');
		if(path != null)
		{
			var data:Dynamic = parseFile(path);
			if(data != null && data.healthIcon != null) return VSliceConvert.str(data.healthIcon.id, char);
		}
		return char;
	}

	// "#F9CF51" -> [249, 207, 81]
	static function parseColor(color:String):Array<Int>
	{
		if(color.startsWith('#')) color = color.substr(1);
		if(color.length < 6) return defaultColor;

		var value:Null<Int> = Std.parseInt('0x' + color.substr(color.length - 6));
		if(value == null) return defaultColor;
		return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
	}

	// ------------------------------------------------------------------------------------------
	// Songs
	// ------------------------------------------------------------------------------------------

	/**
	 * Loads a chart of the current mod the same way `Song.getChart()` is asked for one ("song-hard" from the "song" folder).
	 * Returns null when the current mod isn't a Polymod one or doesn't have that song and difficulty.
	 */
	public static function getChart(jsonInput:String, folder:String):SwagSong
	{
		var mod:String = Mods.currentModDirectory;
		if(!isPolymod(mod)) return null;

		var key:String = Paths.formatToSongPath(folder);
		var songData:VSliceSong = getData(mod).songs.get(key);
		if(songData == null) return null;

		// "song" is the Normal chart, anything else has the difficulty after the song's name
		var input:String = Paths.formatToSongPath(jsonInput);
		if(!input.startsWith(key)) return null;

		var difficulty:String = input.substr(key.length);
		if(difficulty.startsWith('-')) difficulty = difficulty.substr(1);
		if(difficulty.length < 1) difficulty = Paths.formatToSongPath(Difficulty.getDefault());

		// Story Mode always plays the default charts, Freeplay the ones of the picked player.
		// Variations can repeat difficulty names (both the default and the Pico one have "hard"), so the order matters
		var variations:Array<VSliceVariation> = songData.variations;
		if(!PlayState.isStoryMode)
		{
			var playable:Array<VSliceVariation> = getPlayableVariations(songData);
			variations = playable.concat(variations.filter((curVariation) -> !playable.contains(curVariation)));
		}

		var variation:VSliceVariation = null;
		var difficultyId:String = null;
		for (curVariation in variations)
		{
			for (diff in curVariation.difficulties)
			{
				if(Paths.formatToSongPath(diff) == difficulty)
				{
					variation = curVariation;
					difficultyId = diff;
					break;
				}
			}
			if(variation != null) break;
		}
		if(variation == null) return null;

		return buildChart(mod, songData, variation, difficultyId, variation.metadata, parseFile(variation.chartPath));
	}

	/**
	 * Id of the variation a difficulty of one of the mod's songs is played with outside of Story Mode: the same pick `getChart()` makes.
	 * Null if the mod isn't a V-Slice one or doesn't have that song.
	 *
	 * @param difficulty 	Name of the difficulty, the way it's on the song's files.
	 */
	public static function getVariationId(mod:String, song:String, difficulty:String):String
	{
		if(!isPolymod(mod) || song == null || difficulty == null) return null;

		var songData:VSliceSong = getData(mod).songs.get(Paths.formatToSongPath(song));
		if(songData == null) return null;

		var wanted:String = Paths.formatToSongPath(difficulty);
		var playable:Array<VSliceVariation> = getPlayableVariations(songData);
		for (variation in playable.concat(songData.variations.filter((cur) -> !playable.contains(cur))))
			for (diff in variation.difficulties)
				if(Paths.formatToSongPath(diff) == wanted)
					return variation.id;
		return null;
	}

	// A difficulty of a song's variation as a Psych chart, with what the engine needs to know about where it came from
	static function buildChart(mod:String, songData:VSliceSong, variation:VSliceVariation, difficultyId:String, metadata:Dynamic, chart:Dynamic):SwagSong
	{
		var key:String = Paths.formatToSongPath(songData.id);
		var song:SwagSong = cast VSliceConvert.convertChart(metadata, chart, difficultyId);
		if(song == null) return null;

		// from here on the engine finds everything by the song's name
		song.song = songData.name;
		Reflect.setField(song, 'displayName', VSliceConvert.str(metadata.songName, songData.name)); //the one that's shown

		// stages the mod doesn't have come from the base game: V-Slice's own when the engine's V-Slice content has it (the Erect ones,
		// with the names their scripts look for), the engine's version of it otherwise, which goes by another name
		var stageFile:String = 'data/stages/${song.stage}.json';
		if(findFile(mod, stageFile) == null && (mod == BASE_MOD || findFile(BASE_MOD, stageFile) == null))
			song.stage = VSliceConvert.psychStageName(song.stage);

		var audioFolder:String = 'songs/${songData.id}/';
		var audio = VSliceConvert.resolveAudio(metadata, variation.id, (file) -> findFile(mod, '$audioFolder$file.${Paths.SOUND_EXT}') != null);

		// the kinds of events the chart has, as V-Slice calls them (some are converted to Psych's own, with other names)
		var eventKinds:Array<String> = [];
		for (event in VSliceConvert.list((chart != null) ? chart.events : null))
		{
			var kind:String = (event != null) ? VSliceConvert.str(event.e, '') : '';
			if(kind.length > 0 && !eventKinds.contains(kind)) eventKinds.push(kind);
		}

		// Paths.inst() and Paths.voices() read the file names from here, they're relative to the "songs" folder
		song.vslice = {
			key: key,
			eventKinds: eventKinds,
			// the events' values as they're written, which Psych's events only keep as two texts (scripts get these, see VSliceScripts)
			eventValues: [for (event in VSliceConvert.list((chart != null) ? chart.events : null)) if(event != null) {t: event.t, e: event.e, v: event.v}],
			mod: mod,
			variation: variation.id,
			noteStyle: VSliceConvert.str(metadata.playData.noteStyle, 'funkin'),
			noGirlfriend: (song.gfVersion == null || song.gfVersion.length < 1),

			// what scripts read from the chart
			difficulty: difficultyId,
			album: VSliceConvert.str(metadata.playData.album, 'volume1'),
			stickerPack: VSliceConvert.str(metadata.playData.stickerPack, null),
			artist: VSliceConvert.str(metadata.artist, 'Unknown'),
			charter: VSliceConvert.str(metadata.charter, 'Unknown'),
			characters: metadata.playData.characters,

			inst: '${songData.id}/${audio.inst}',
			playerVoices: (audio.playerVoices != null) ? '${songData.id}/${audio.playerVoices}' : null,
			opponentVoices: (audio.opponentVoices != null) ? '${songData.id}/${audio.opponentVoices}' : null,
			voices: (audio.voices != null) ? '${songData.id}/${audio.voices}' : null
		};
		return song;
	}

	// The variation and the difficulty a chart made by getChart() is from, null if they aren't there anymore
	static function findChartSource(song:SwagSong):{mod:String, songData:VSliceSong, variation:VSliceVariation, difficultyId:String}
	{
		var info:Dynamic = (song != null) ? song.vslice : null;
		if(info == null || info.mod == null || info.key == null || !isPolymod(info.mod)) return null;

		var songData:VSliceSong = getData(info.mod).songs.get(info.key);
		if(songData == null) return null;

		for (variation in songData.variations)
		{
			if(variation.id != info.variation) continue;

			for (diff in variation.difficulties)
				if(diff == info.difficulty)
					return {mod: info.mod, songData: songData, variation: variation, difficultyId: diff};
		}
		return null;
	}

	/**
	 * The notes one of the difficulties of a V-Slice song has on its chart file, the way they're written there (`t`, `d`, `l`, `k` and `p`).
	 * It doesn't have to be one of the difficulties that are played: the base game keeps the times of what happens on some stages
	 * on one called "picospeaker". Null if the song isn't a V-Slice one or its file doesn't have that difficulty.
	 *
	 * @param song 			The chart being played, to know which song and mod it is.
	 * @param variationId 	Variation whose file is read, the one being played if not given.
	 */
	public static function getChartNotes(song:SwagSong, difficultyId:String, ?variationId:String):Array<Dynamic>
	{
		var info:Dynamic = (song != null) ? song.vslice : null;
		if(info == null || info.mod == null || info.key == null || difficultyId == null || !isPolymod(info.mod)) return null;

		var songData:VSliceSong = getData(info.mod).songs.get(info.key);
		if(songData == null) return null;

		if(variationId == null || variationId.length < 1) variationId = info.variation;
		for (variation in songData.variations)
		{
			if(variation.id != variationId) continue;

			var chart:Dynamic = parseFile(variation.chartPath);
			var notes:Dynamic = (chart != null && chart.notes != null) ? Reflect.field(chart.notes, difficultyId) : null;
			return Std.isOfType(notes, Array) ? notes : null;
		}
		return null;
	}

	/**
	 * If a chart was made out of the V-Slice files of a mod, which is where its changes have to be saved to.
	 * One that was read from a Psych chart file (`Song.chartPath`) is that file's, whatever it says about where it first came from.
	 */
	public static function isVSliceChart(song:SwagSong):Bool
	{
		return song != null && song.vslice != null && song.vslice.mod != null && song.vslice.key != null && Song.chartPath == null;
	}

	static var warnedExports:Map<String, Bool> = [];

	/**
	 * Tells who's using an editor that what's being saved isn't what the game loads, once for each kind of thing.
	 * The editors work with what V-Slice files were converted to, and save Psych files: the game keeps reading the V-Slice ones.
	 *
	 * @param kind 	What's being saved: "character" or "stage".
	 */
	public static function warnPsychExport(kind:String):Void
	{
		if(warnedExports.exists(kind)) return;
		warnedExports.set(kind, true);

		lime.app.Application.current.window.alert('This $kind comes from a V-Slice mod.\n\n'
			+ 'What is saved here is a Psych Engine file made out of it, which the game does not use: '
			+ 'while the mod has the V-Slice file of this $kind, that is the one that gets loaded.\n\n'
			+ 'To really change it, edit the V-Slice file of the mod.', 'V-Slice $kind');
	}

	/**
	 * Reads a chart made by getChart() from its files again: the same song, variation and difficulty. Null if they can't be found anymore.
	 */
	public static function reloadChart(song:SwagSong):SwagSong
	{
		clearCache();

		var source = findChartSource(song);
		if(source == null) return null;

		return buildChart(source.mod, source.songData, source.variation, source.difficultyId, source.variation.metadata, parseFile(source.variation.chartPath));
	}

	// Files that were already copied to the backups folder since the game was opened
	static var backedUp:Map<String, Bool> = [];

	/**
	 * Saves the changes made to a chart that came from a V-Slice song to the files it came from: the song's "chart" file
	 * (its notes on that difficulty, its speed, the events) and its "metadata" file (BPM, characters, stage, name).
	 *
	 * Only what was really changed is written (see `VSliceConvert.updateChart()`), nothing is ever saved as a Psych chart.
	 * The first time a file is about to be changed its original goes to the "backups" folder, next to the game.
	 *
	 * @return A message about what was done, and if it's an error.
	 */
	public static function saveChart(song:SwagSong):{message:String, error:Bool}
	{
		try
		{
			clearCache();

			var source = findChartSource(song);
			if(source == null) return {message: 'The V-Slice song this chart came from was not found anymore!', error: true};

			var chartPath:String = source.variation.chartPath;
			var metadataPath:String = source.variation.metadataPath;

			// as they are on the disk right now
			var chart:Dynamic = parseFile(chartPath);
			var metadata:Dynamic = parseFile(metadataPath);
			if(chart == null || metadata == null) return {message: 'Could not read the V-Slice files of the song!', error: true};

			var fresh:SwagSong = buildChart(source.mod, source.songData, source.variation, source.difficultyId, metadata, chart);
			if(fresh == null) return {message: 'The song\'s files do not have the difficulty "${source.difficultyId}" anymore!', error: true};

			var result = VSliceConvert.updateChart(metadata, chart, source.difficultyId, fresh, song);
			if(!result.chartChanged && !result.metadataChanged) return {message: 'Nothing was changed, the V-Slice files were left as they are.', error: false};

			var saved:Array<String> = [];
			if(result.chartChanged)
			{
				backupFile(chartPath);
				File.saveContent(chartPath, states.editors.content.PsychJsonPrinter.print(chart, ['events', 'notes', 'scrollSpeed']));
				saved.push(haxe.io.Path.withoutDirectory(chartPath));
			}
			if(result.metadataChanged)
			{
				backupFile(metadataPath);
				File.saveContent(metadataPath, states.editors.content.PsychJsonPrinter.print(metadata, ['characters', 'difficulties', 'timeChanges']));
				saved.push(haxe.io.Path.withoutDirectory(metadataPath));
			}

			clearCache();
			return {message: 'Saved to the V-Slice files of "${source.mod}": ' + saved.join(' and ') + ' (' + result.changes.join(', ') + ')', error: false};
		}
		catch(e:Dynamic)
		{
			trace('Error saving a V-Slice chart: $e');
			return {message: 'Error saving the V-Slice files: $e', error: true};
		}
	}

	static function backupFile(path:String):Void
	{
		if(backedUp.exists(path) || !FileSystem.exists(path)) return;

		if(!FileSystem.isDirectory('backups')) FileSystem.createDirectory('backups');

		var name:String = haxe.io.Path.withoutDirectory(path);
		var extension:Int = name.lastIndexOf('.');
		var stamp:String = DateTools.format(Date.now(), '_%Y-%m-%d_%H-%M-%S');
		File.copy(path, 'backups/' + ((extension > 0) ? name.substr(0, extension) + stamp + name.substr(extension) : name + stamp));
		backedUp.set(path, true);
	}

	/**
	 * A song of a Polymod mod by the name the menus use for it, null if the mod doesn't have it.
	 */
	public static function getSong(mod:String, name:String):VSliceSong
	{
		return isPolymod(mod) ? getData(mod).songs.get(Paths.formatToSongPath(name)) : null;
	}

	/**
	 * The songs of a Polymod mod, by the name the menus use for them.
	 */
	public static function listSongs(mod:String):Array<VSliceSong>
	{
		return isPolymod(mod) ? [for (song in getData(mod).songs) song] : [];
	}

	/**
	 * The V-Slice mods the songs scripts ask about can come from: the current one first, then the others that are on, then the base
	 * game's content (on V-Slice they're all on top of each other).
	 */
	public static function songMods():Array<String>
	{
		var list:Array<String> = [];
		var current:String = Mods.currentModDirectory;
		if(isPolymod(current)) list.push(current);
		for (mod in Mods.parseList().enabled)
			if(!list.contains(mod) && isPolymod(mod))
				list.push(mod);
		if(!list.contains(BASE_MOD) && isPolymod(BASE_MOD)) list.push(BASE_MOD);
		return list;
	}

	/**
	 * Instrumental of one of the song's variations, relative to the "songs" folder and without extension ("bopeebo/Inst-erect").
	 */
	public static function getVariationInst(mod:String, song:VSliceSong, variation:VSliceVariation):String
	{
		var audioFolder:String = 'songs/${song.id}/';
		var audio = VSliceConvert.resolveAudio(variation.metadata, variation.id, (file) -> findFile(mod, '$audioFolder$file.${Paths.SOUND_EXT}') != null);
		return '${song.id}/${audio.inst}';
	}

	/**
	 * Audio file names of the loaded song (PlayState.SONG) if it came from a V-Slice chart and it's the given song, null otherwise.
	 */
	public static function getSongAudio(song:String):Dynamic
	{
		var data:Dynamic = (PlayState.SONG != null) ? PlayState.SONG.vslice : null;
		if(data == null || data.mod != Mods.currentModDirectory || data.key != Paths.formatToSongPath(song)) return null;
		return data;
	}

	// ------------------------------------------------------------------------------------------
	// Stages and Characters
	// ------------------------------------------------------------------------------------------

	/**
	 * Loads a V-Slice stage of the current mod as a Psych one, returns null if there's none with that name.
	 */
	public static function getStageFile(stage:String):StageFile
	{
		var mod:String = Mods.currentModDirectory;
		if(!isPolymod(mod) || stage == null) return null;

		var path:String = findFile(mod, 'data/stages/$stage.json');
		if(path == null && mod != BASE_MOD) path = findFile(BASE_MOD, 'data/stages/$stage.json'); //(one of the base game's)
		if(path == null) return null;

		// the UI style and the girlfriend being there or not depend on the song on V-Slice, not on the stage
		var song:SwagSong = PlayState.SONG;
		var songData:Dynamic = (song != null && song.stage == stage) ? song.vslice : null;

		var pixelUI:Bool = (songData != null && songData.noteStyle == 'pixel');
		var noGirlfriend:Bool = (songData != null && songData.noGirlfriend == true);
		return cast VSliceConvert.convertStage(parseFile(path), pixelUI, noGirlfriend);
	}

	/**
	 * Loads a V-Slice character of the current mod as a Psych character file, returns null if there's none with that name.
	 */
	public static function getCharacterFile(char:String, isPlayer:Bool):Dynamic
	{
		var mod:String = Mods.currentModDirectory;
		if(!isPolymod(mod) || char == null || char.length < 1) return null;

		var path:String = findFile(mod, 'data/characters/$char.json');
		return (path != null) ? VSliceConvert.convertCharacter(parseFile(path), char, isPlayer) : null;
	}

	/**
	 * A character of V-Slice's base game (the engine's own V-Slice content), for the songs of the mods that use one there isn't
	 * another version of: on V-Slice the mods are on top of the base game, which has them all. Null if it doesn't have it either.
	 */
	public static function getBaseCharacterFile(char:String, isPlayer:Bool):Dynamic
	{
		var mod:String = Mods.currentModDirectory;
		if(!isPolymod(mod) || mod == BASE_MOD || char == null || char.length < 1) return null;

		var path:String = findFile(BASE_MOD, 'data/characters/$char.json');
		return (path != null) ? VSliceConvert.convertCharacter(parseFile(path), char, isPlayer) : null;
	}

	// ------------------------------------------------------------------------------------------

	static function parseFile(path:String):Dynamic
	{
		try
		{
			var raw:String = File.getContent(path);
			if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1); //UTF-8 BOM
			raw = PolymodMerge.applyToPath(path, raw); //what other mods add to the file, see PolymodMerge

			try
			{
				return Json.parse(raw);
			}
			catch(e:Dynamic)
			{
				return tjson.TJSON.parse(raw); //more forgiving with hand written files
			}
		}
		catch(e:Dynamic)
		{
			trace('Could not read "$path": $e');
		}
		return null;
	}
}
#end
