package funkin.data.song;

/**
 * Where V-Slice scripts ask about the songs: the one being played, and the ones of the V-Slice mods that are on and of the base game
 * (scripts of menus open them with `LoadingState.loadPlayState()`). Also reads the data files music can come with.
 */
class SongRegistry
{
	public static var instance:SongRegistry = new SongRegistry();

	public function new() {}

	/**
	 * The song with that id, null if there's none: the one being played is the one PlayState has, the others are found on the mods.
	 */
	public function fetchEntry(id:String, ?params:Dynamic):funkin.play.song.Song
	{
		if(id == null) return null;

		var game:funkin.play.PlayState = funkin.play.PlayState.instance;
		if(game != null && game.currentSong != null && backend.Paths.formatToSongPath(game.currentSong.id) == backend.Paths.formatToSongPath(id))
			return game.currentSong;

		#if MODS_ALLOWED
		for (mod in backend.PolymodCompat.songMods())
		{
			var data:backend.PolymodCompat.VSliceSong = backend.PolymodCompat.getSong(mod, id);
			if(data == null) continue;

			var song:funkin.play.song.Song = new funkin.play.song.Song(data.id, params);
			song.songName = data.name;
			return song;
		}
		#end
		return null;
	}

	public function hasEntry(id:String):Bool
	{
		return fetchEntry(id) != null;
	}

	public function listEntryIds():Array<String>
	{
		var ids:Array<String> = [];
		var game:funkin.play.PlayState = funkin.play.PlayState.instance;
		if(game != null && game.currentSong != null) ids.push(game.currentSong.id);

		#if MODS_ALLOWED
		for (mod in backend.PolymodCompat.songMods())
			for (song in backend.PolymodCompat.listSongs(mod))
				if(!ids.contains(song.id)) ids.push(song.id);
		#end
		return ids;
	}

	/**
	 * The data file of a music ("music/(id)/(id)-metadata.json"): its name, its artist and mostly its tempo (`timeChanges`),
	 * which scripts give to a Conductor of their own to do things on the beat of a cutscene's music. Null if there's none.
	 */
	public function parseMusicData(id:String, ?variation:String):Dynamic
	{
		if(id == null) return null;

		var suffix:String = (variation != null && variation.length > 0 && variation != 'default') ? '-$variation' : '';
		for (key in ['music/$id/$id-metadata$suffix.json', 'music/$id-metadata$suffix.json'])
		{
			var raw:String = backend.Paths.getTextFromFile(key);
			if(raw == null) continue;

			try
			{
				if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1);
				return haxe.Json.parse(raw);
			}
			catch(e:Dynamic)
			{
				trace('Could not read "$key": $e');
			}
		}
		return null;
	}

	public function parseMusicDataRaw(contents:String, ?fileName:String):Dynamic
	{
		try
		{
			return haxe.Json.parse(contents);
		}
		catch(e:Dynamic) {}
		return null;
	}
}
