package funkin.play.song;

/**
 * What V-Slice song scripts extend. The script whose id is the one of the song being played receives its events,
 * the one made for the variation being played (`super('song', {variation: 'erect'})`) if there is one.
 */
class Song extends funkin.modding.ScriptedBase
{
	public var id(default, null):String;
	public var variation(default, null):String = 'default';

	/**
	 * Name shown on the menus, filled in for the song being played.
	 */
	public var songName:String = null;
	public var songArtist:String = null;
	public var charter:String = null;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
		if(params != null && params.variation != null) variation = params.variation;
	}

	/**
	 * If the song gets the "new" sticker on V-Slice's Freeplay, scripts say so by overriding it. Nothing here shows it yet.
	 */
	public function isSongNew(currentDifficulty:String, currentVariation:String):Bool
	{
		return false;
	}

	public function listAltInstrumentalIds(difficultyId:String, variationId:String):Array<String>
	{
		return [];
	}

	/**
	 * A difficulty of the song, as it's on its chart file. For the scripts that read charts that aren't played:
	 * the base game keeps when things happen on some of its stages on a difficulty called "picospeaker".
	 * Null if the song being played doesn't have it.
	 */
	public function getDifficulty(?diffId:String, ?variation:String):SongDifficulty
	{
		#if MODS_ALLOWED
		var chart = states.PlayState.SONG;
		if(chart == null || chart.vslice == null) return null;

		if(diffId == null) diffId = chart.vslice.difficulty;
		if(variation == null || variation.length < 1) variation = chart.vslice.variation;

		var raw:Array<Dynamic> = backend.PolymodCompat.getChartNotes(chart, diffId, variation);
		if(raw == null) return null;

		var notes:Array<funkin.data.song.SongData.SongNoteData> = [];
		for (note in raw)
		{
			if(note == null || note.t == null) continue;

			var kind:String = (note.k != null) ? Std.string(note.k) : '';
			notes.push(new funkin.data.song.SongData.SongNoteData(note.t, (note.d != null) ? Std.int(note.d) : 0, (note.l != null) ? note.l : 0, kind,
				Std.isOfType(note.p, Array) ? note.p : null));
		}
		return new SongDifficulty(this, diffId, variation, notes);
		#else
		return null;
		#end
	}

	public function toString():String
	{
		return 'Song($id)';
	}
}

/**
 * One of the difficulties of a song: its notes, the way V-Slice scripts read them.
 */
class SongDifficulty
{
	public var song(default, null):Song;
	public var difficulty(default, null):String;
	public var variation(default, null):String;
	public var notes:Array<funkin.data.song.SongData.SongNoteData>;

	public function new(song:Song, difficulty:String, variation:String, notes:Array<funkin.data.song.SongData.SongNoteData>)
	{
		this.song = song;
		this.difficulty = difficulty;
		this.variation = variation;
		this.notes = notes;
	}

	public function toString():String
	{
		return 'SongDifficulty($difficulty, $variation)';
	}
}
