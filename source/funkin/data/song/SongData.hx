package funkin.data.song;

import funkin.util.Constants;
import funkin.util.tools.ICloneable;
import thx.semver.Version;

using funkin.util.tools.ArrayTools;
using funkin.util.tools.MapTools;
import funkin.data.song.SongRegistry;
// (V-Slice's SongEventDataRaw is the engine's, scripts get the same one)
typedef SongEventDataRaw = funkin.data.song.SongData.SongEventData;

// (V-Slice's SongNoteDataRaw is the engine's, scripts get the same one)
typedef SongNoteDataRaw = funkin.data.song.SongData.SongNoteData;

/**
 * Only here so `funkin.data.song.SongData.SongEventData` and the like lead to the classes below, like on V-Slice.
 */
class SongData {}

/**
 * A change of tempo of a V-Slice song (`timeChanges` of its metadata: "t", "b", "bpm", "n", "d" there).
 */
class SongTimeChange implements ICloneable<SongTimeChange>
{
	public var timeStamp:Float;
	public var beatTime:Float;
	public var bpm:Float;
	public var timeSignatureNum:Int;
	public var timeSignatureDen:Int;
	public var beatTuplets:Array<Int>;

	public function new(timeStamp:Float, bpm:Float, timeSignatureNum:Int = 4, timeSignatureDen:Int = 4, beatTime:Float = 0, ?beatTuplets:Array<Int>)
	{
		this.timeStamp = timeStamp;
		this.bpm = bpm;
		this.timeSignatureNum = timeSignatureNum;
		this.timeSignatureDen = timeSignatureDen;
		this.beatTime = beatTime;
		this.beatTuplets = (beatTuplets != null) ? beatTuplets : [4, 4, 4, 4];
	}

	public function clone():SongTimeChange
	{
		return new SongTimeChange(timeStamp, bpm, timeSignatureNum, timeSignatureDen, beatTime, (beatTuplets != null) ? beatTuplets.copy() : null);
	}

	public function toString():String return 'SongTimeChange($timeStamp ms, $bpm bpm)';
}

/**
 * An event of a V-Slice chart, as scripts get it.
 */
class SongEventData implements ICloneable<SongEventData>
{
	public var time:Float;
	public var eventKind:String;
	public var value:Dynamic;
	public var activated:Bool = false;

	public function new(time:Float, eventKind:String, value:Dynamic = null)
	{
		this.time = time;
		this.eventKind = eventKind;
		this.value = value;
	}

	public function getStepTime(force:Bool = false):Float
	{
		return backend.Conductor.getStep(time);
	}

	/**
	 * The event's values as an object, whatever they were written as.
	 */
	public function valueAsStruct(defaultKey:String = 'key'):Dynamic
	{
		if(value == null) return {};
		if(Std.isOfType(value, Array) || !Reflect.isObject(value) || Std.isOfType(value, String))
		{
			var result:Dynamic = {};
			Reflect.setField(result, defaultKey, value);
			return result;
		}
		return value;
	}

	public function getDynamic(key:String):Dynamic
	{
		return (value == null || !Reflect.isObject(value)) ? null : Reflect.field(value, key);
	}

	public function getBool(key:String):Null<Bool>
	{
		var result:Dynamic = getDynamic(key);
		return (result == null) ? null : (result == true || result == 'true');
	}

	public function getInt(key:String):Null<Int>
	{
		var result:Dynamic = getDynamic(key);
		if(result == null) return null;
		if(Std.isOfType(result, Int)) return result;
		if(Std.isOfType(result, Float)) return Std.int(result);
		return Std.parseInt(Std.string(result));
	}

	public function getFloat(key:String):Null<Float>
	{
		var result:Dynamic = getDynamic(key);
		if(result == null) return null;
		if(Std.isOfType(result, Float)) return result;

		var parsed:Float = Std.parseFloat(Std.string(result));
		return Math.isNaN(parsed) ? null : parsed;
	}

	public function getString(key:String):String
	{
		var result:Dynamic = getDynamic(key);
		return (result == null) ? null : Std.string(result);
	}

	public function getArray(key:String):Array<Dynamic>
	{
		var result:Dynamic = getDynamic(key);
		return Std.isOfType(result, Array) ? result : null;
	}

	// The same list, V-Slice has one of these for each kind of thing it can have
	public function getBoolArray(key:String):Array<Dynamic> return getArray(key);
	public function getFloatArray(key:String):Array<Dynamic> return getArray(key);
	public function getIntArray(key:String):Array<Dynamic> return getArray(key);
	public function getStringArray(key:String):Array<Dynamic> return getArray(key);

	public function clone():SongEventData
	{
		return new SongEventData(time, eventKind, value);
	}

	public function toString():String
	{
		return 'SongEventData($time ms, $eventKind: $value)';
	}
}

/**
 * A note of a V-Slice chart, as scripts get it. Made out of the Psych notes, which only know their own side's directions.
 */
class SongNoteData implements ICloneable<SongNoteData>
{
	public var time:Float;
	public var data:Int; //0 to 3 is the player and 4 to 7 the opponent
	public var length:Float;
	public var kind:String;
	public var params:Array<Dynamic>;

	public function new(time:Float, data:Int, length:Float = 0, kind:String = '', ?params:Array<Dynamic>)
	{
		this.time = time;
		this.data = data;
		this.length = length;
		this.kind = kind;
		this.params = (params != null) ? params : [];
	}

	public function getDirection(strumlineSize:Int = 4):Int
	{
		return data % strumlineSize;
	}

	public function getDirectionName(strumlineSize:Int = 4):String
	{
		return ['left', 'down', 'up', 'right'][getDirection(strumlineSize) % 4];
	}

	public function getStrumlineIndex(strumlineSize:Int = 4):Int
	{
		return Math.floor(data / strumlineSize);
	}

	public function getMustHitNote(strumlineSize:Int = 4):Bool
	{
		return getStrumlineIndex(strumlineSize) == 0;
	}

	public function getStepTime(force:Bool = false):Float
	{
		return backend.Conductor.getStep(time);
	}

	public var isHoldNote(get, never):Bool;
	inline function get_isHoldNote():Bool
		return length > 0;

	public function clone():SongNoteData
	{
		return new SongNoteData(time, data, length, kind, (params != null) ? params.copy() : null);
	}

	public function toString():String
	{
		return 'SongNoteData($time ms, $data' + ((kind != null && kind.length > 0) ? ', $kind)' : ')');
	}
}

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum abstract SongTimeFormat(String) from String to String
{
	var TICKS = 'ticks';
	var FLOAT = 'float';
	var MILLISECONDS = 'ms';
}

// (V-Slice's, for its classes and scripts)
/**
 * Data containing information about a song.
 * It should contain all the data needed to display a song in the Freeplay menu, or to load the assets required to play its chart.
 * Data which is only necessary in-game should be stored in the SongChartData.
 */
@:nullSafety
class SongMetadata implements ICloneable<SongMetadata>
{
  /**
   * A semantic versioning string for the song data format.
   *
   */
  @:jcustomparse(funkin.data.DataParse.semverVersion) @:jcustomwrite(funkin.data.DataWrite.semverVersion)
  public var version:Version;

  @:default("Unknown")
  public var songName:String;
  @:default("Unknown")
  public var artist:String;
  @:optional
  public var charter:Null<String> = null;
  @:optional @:default(96)
  public var divisions:Null<Int>; // Optional field
  @:optional @:default(false)
  public var looped:Bool;

  /**
   * Instrumental and vocal offsets.
   * Defaults to an empty SongOffsets object.
   */
  @:optional
  public var offsets:Null<SongOffsets>;

  /**
   * Data relating to the song's gameplay.
   */
  public var playData:SongPlayData;

  public var generatedBy:String;
  @:optional @:default(funkin.data.song.SongData.SongTimeFormat.MILLISECONDS)
  public var timeFormat:SongTimeFormat;
  public var timeChanges:Array<SongTimeChange>;

  /**
   * Defaults to `Constants.DEFAULT_VARIATION`. Populated later.
   */
  @:jignored
  public var variation:String;

  public function new(songName:String, artist:String, ?charter:String, ?variation:String)
  {
    this.version = SongRegistry.SONG_METADATA_VERSION;
    this.songName = songName;
    this.artist = artist;
    this.charter = (charter == null) ? null : charter;
    this.timeFormat = 'ms';
    this.divisions = null;
    this.offsets = new SongOffsets();
    this.timeChanges = [new SongTimeChange(0, 100)];
    this.looped = false;
    this.playData = new SongPlayData();
    this.playData.songVariations = [];
    this.playData.difficulties = [];
    this.playData.characters = new SongCharacterData('bf', 'gf', 'dad');
    this.playData.stage = 'mainStage';
    this.playData.noteStyle = Constants.DEFAULT_NOTE_STYLE;
    this.generatedBy = SongRegistry.DEFAULT_GENERATEDBY;
    // Variation ID.
    this.variation = (variation == null) ? Constants.DEFAULT_VARIATION : variation;
  }

  /**
   * Create a copy of this SongMetadata with the same information.
   * @param newVariation Set to a new variation ID to change the new metadata.
   * @return The cloned SongMetadata
   */
  public function clone():SongMetadata
  {
    var result:SongMetadata = new SongMetadata(this.songName, this.artist, this.charter, this.variation);
    result.version = this.version;
    result.timeFormat = this.timeFormat;
    result.divisions = this.divisions;
    result.offsets = this.offsets != null ? this.offsets.clone() : new SongOffsets(); // if no song offsets found (aka null), so just create new ones
    result.timeChanges = this.timeChanges.deepClone();
    result.looped = this.looped;
    result.playData = this.playData.clone();
    result.generatedBy = this.generatedBy;

    return result;
  }

  /**
   * Serialize this SongMetadata into a JSON string.
   * @param pretty Whether the JSON should be big ol string (false),
   * or formatted with tabs (true)
   * @return The JSON string.
   */
  public function serialize(pretty:Bool = true):String
  {
    // Update generatedBy and version before writing.
    updateVersionToLatest();

    // This might not be a very wise hack, but it works.
    #if FEATURE_CHART_EDITOR
    if (Std.isOfType(FlxG.state, ChartEditorState))
    {
      var state:ChartEditorState = cast(FlxG.state, ChartEditorState);

      final songLength:Float = @:privateAccess state.songLengthInMs;
      if (playData.previewStart > 1) playData.previewStart /= songLength;
      if (playData.previewEnd > 1) playData.previewEnd /= songLength;
    }
    #end

    var ignoreNullOptionals = true;
    var writer = new json2object.JsonWriter<SongMetadata>(ignoreNullOptionals);
    // I believe @:jignored should be ignored by the writer?
    // var output = this.clone();
    // output.variation = null; // Not sure how to make a field optional on the reader and ignored on the writer.
    return writer.write(this, pretty ? ' ' : null);
  }

  public function updateVersionToLatest():Void
  {
    this.version = SongRegistry.SONG_METADATA_VERSION;
    this.generatedBy = SongRegistry.DEFAULT_GENERATEDBY;
  }

  /**
   * Produces a string representation suitable for debugging.
   */
  public function toString():String
  {
    return 'SongMetadata(${this.songName} by ${this.artist}, charted by ${this.charter}, variation ${this.variation})';
  }
}

// (V-Slice's, for its classes and scripts)
/**
 * Metadata for a song only used for the music.
 * For example, the menu music.
 */
class SongMusicData implements ICloneable<SongMusicData>
{
  /**
   * A semantic versioning string for the song data format.
   *
   */
  @:jcustomparse(funkin.data.DataParse.semverVersion) @:jcustomwrite(funkin.data.DataWrite.semverVersion)
  public var version:Version;

  @:default("Unknown")
  public var songName:String;
  @:default("Unknown")
  public var artist:String;
  @:optional @:default(96)
  public var divisions:Null<Int>; // Optional field
  @:optional @:default(false)
  public var looped:Null<Bool>;
  // @:default(funkin.data.song.SongRegistry.DEFAULT_GENERATEDBY)
  public var generatedBy:String;
  // @:default(funkin.data.song.SongData.SongTimeFormat.MILLISECONDS)
  public var timeFormat:SongTimeFormat;
  // @:default(funkin.data.song.SongData.SongTimeChange.DEFAULT_SONGTIMECHANGES)
  public var timeChanges:Array<SongTimeChange>;

  /**
   * Defaults to `Constants.DEFAULT_VARIATION`. Populated later.
   */
  @:jignored
  public var variation:String;

  public function new(songName:String, artist:String, variation:String = 'default')
  {
    this.version = SongRegistry.SONG_CHART_DATA_VERSION;
    this.songName = songName;
    this.artist = artist;
    this.timeFormat = 'ms';
    this.divisions = null;
    this.timeChanges = [new SongTimeChange(0, 100)];
    this.looped = false;
    this.generatedBy = SongRegistry.DEFAULT_GENERATEDBY;
    // Variation ID.
    this.variation = variation == null ? Constants.DEFAULT_VARIATION : variation;
  }

  public function updateVersionToLatest():Void
  {
    this.version = SongRegistry.SONG_MUSIC_DATA_VERSION;
    this.generatedBy = SongRegistry.DEFAULT_GENERATEDBY;
  }

  public function clone():SongMusicData
  {
    var result:SongMusicData = new SongMusicData(this.songName, this.artist, this.variation);
    result.version = this.version;
    result.timeFormat = this.timeFormat;
    result.divisions = this.divisions;
    result.timeChanges = this.timeChanges.clone();
    result.looped = this.looped;
    result.generatedBy = this.generatedBy;

    return result;
  }

  /**
   * Produces a string representation suitable for debugging.
   */
  public function toString():String
  {
    return 'SongMusicData(${this.songName} by ${this.artist}, variation ${this.variation})';
  }
}

// (V-Slice's, for its classes and scripts)
class SongPlayData implements ICloneable<SongPlayData>
{
  /**
   * The variations this song has. The associated metadata files should exist.
   */
  @:default([]) @:optional
  public var songVariations:Array<String>;

  /**
   * The difficulties contained in this song's chart file.
   */
  public var difficulties:Array<String>;

  /**
   * The characters used by this song.
   */
  public var characters:SongCharacterData;

  /**
   * The stage used by this song.
   */
  public var stage:String;

  /**
   * The note style used by this song.
   */
  public var noteStyle:String;

  /**
   * The difficulty ratings for this song as displayed in Freeplay.
   * Key is a difficulty ID.
   */
  @:optional @:default(['normal' => 0]) @:order(funkin.util.Constants.DEFAULT_DIFFICULTY_LIST_FULL)
  public var ratings:Map<String, Int>;

  /**
   * The album ID for the album to display in Freeplay.
   * If `null`, display no album.
   */
  @:optional
  public var album:Null<String>;

  /**
   * An external image link for the opponent's health icon.
   * This is used for Discord Rich Presence.
   */
  @:optional
  public var discordRPCImage:String;

  /**
   * The sticker pack for the song to use during transitions.
   * If `null`, display the character's sticker pack.
   */
  @:optional
  public var stickerPack:Null<String>;

  /**
   * The start time for the audio preview in Freeplay.
   * Defaults to 0 seconds in.
   * @since `2.2.2`
   */
  @:optional @:default(funkin.util.Constants.DEFAULT_PREVIEW_START_TIME)
  public var previewStart:Float;

  /**
   * The end time for the audio preview in Freeplay.
   * Defaults to 20% seconds in.
   * @since `2.2.2`
   */
  @:optional @:default(funkin.util.Constants.DEFAULT_PREVIEW_END_TIME)
  public var previewEnd:Float;

  public function new()
  {
    ratings = new Map<String, Int>();
  }

  public function clone():SongPlayData
  {
    // TODO: This sucks! If you forget to update this you get weird behavior.
    var result:SongPlayData = new SongPlayData();
    result.songVariations = this.songVariations.clone();
    result.difficulties = this.difficulties.clone();
    result.characters = this.characters.clone();
    result.stage = this.stage;
    result.noteStyle = this.noteStyle;
    result.ratings = this.ratings.clone();
    result.album = this.album;
    result.previewStart = this.previewStart;
    result.previewEnd = this.previewEnd;

    return result;
  }

  /**
   * Produces a string representation suitable for debugging.
   */
  public function toString():String
  {
    return 'SongPlayData(${this.songVariations}, ${this.difficulties})';
  }
}

// (V-Slice's, for its classes and scripts)
/**
 * Information about the characters used in this variation of the song.
 * Create a new variation if you want to change the characters.
 */
class SongCharacterData implements ICloneable<SongCharacterData>
{
  @:optional @:default('')
  public var player:String = '';
  @:optional @:default('')
  public var girlfriend:String = '';
  @:optional @:default('')
  public var opponent:String = '';
  @:optional @:default('')
  public var instrumental:String = '';
  @:optional @:default([])
  public var altInstrumentals:Array<String> = [];
  @:optional
  public var opponentVocals:Null<Array<String>> = null;
  @:optional
  public var playerVocals:Null<Array<String>> = null;

  public function new(player:String = '', girlfriend:String = '', opponent:String = '', instrumental:String = '', ?altInstrumentals:Array<String>,
      ?opponentVocals:Array<String>, ?playerVocals:Array<String>)
  {
    this.player = player;
    this.girlfriend = girlfriend;
    this.opponent = opponent;
    this.instrumental = instrumental;

    this.altInstrumentals = altInstrumentals ?? [];
    this.opponentVocals = opponentVocals;
    this.playerVocals = playerVocals;

    if (opponentVocals == null) this.opponentVocals = [opponent];
    if (playerVocals == null) this.playerVocals = [player];
  }

  public function clone():SongCharacterData
  {
    var result:SongCharacterData = new SongCharacterData(this.player, this.girlfriend, this.opponent, this.instrumental);
    result.altInstrumentals = this.altInstrumentals.clone();

    return result;
  }

  /**
   * Produces a string representation suitable for debugging.
   */
  public function toString():String
  {
    return 'SongCharacterData(${this.player}, ${this.girlfriend}, ${this.opponent}, ${this.instrumental}, [${this.altInstrumentals.join(', ')}])';
  }
}

// (V-Slice's, for its classes and scripts)
class SongChartData implements ICloneable<SongChartData>
{
  @:jcustomparse(funkin.data.DataParse.semverVersion) @:jcustomwrite(funkin.data.DataWrite.semverVersion)
  public var version:Version;
  @:order(funkin.util.Constants.DEFAULT_DIFFICULTY_LIST_FULL)
  public var scrollSpeed:Map<String, Float>;
  public var events:Array<SongEventData>;
  @:order(funkin.util.Constants.DEFAULT_DIFFICULTY_LIST_FULL)
  public var notes:Map<String, Array<SongNoteData>>;
  public var generatedBy:String;

  /**
   * Defaults to `Constants.DEFAULT_VARIATION`. Populated later.
   */
  @:jignored
  public var variation:String;

  public function new(scrollSpeed:Map<String, Float>, events:Array<SongEventData>, notes:Map<String, Array<SongNoteData>>)
  {
    this.version = SongRegistry.SONG_CHART_DATA_VERSION;

    this.events = events;
    this.notes = notes;
    this.scrollSpeed = scrollSpeed;

    this.generatedBy = SongRegistry.DEFAULT_GENERATEDBY;
  }

  public function getScrollSpeed(diff:String = 'default'):Float
  {
    var result:Float = this.scrollSpeed.get(diff);

    if (result == 0.0 && diff != 'default') return getScrollSpeed('default');

    return (result == 0.0) ? 1.0 : result;
  }

  public function setScrollSpeed(value:Float, diff:String = 'default'):Float
  {
    this.scrollSpeed.set(diff, value);
    return value;
  }

  public function getNotes(diff:String):Array<SongNoteData>
  {
    var result:Array<SongNoteData> = this.notes.get(diff);

    if (result == null && diff != 'normal') return getNotes('normal');

    return (result == null) ? [] : result;
  }

  public function setNotes(value:Array<SongNoteData>, diff:String):Array<SongNoteData>
  {
    this.notes.set(diff, value);
    return value;
  }

  /**
   * Convert this SongChartData into a JSON string.
   */
  public function serialize(pretty:Bool = true):String
  {
    // Update generatedBy and version before writing.
    updateVersionToLatest();

    var ignoreNullOptionals = true;
    var writer = new json2object.JsonWriter<SongChartData>(ignoreNullOptionals);
    return writer.write(this, pretty ? ' ' : null);
  }

  public function updateVersionToLatest():Void
  {
    this.version = SongRegistry.SONG_CHART_DATA_VERSION;
    this.generatedBy = SongRegistry.DEFAULT_GENERATEDBY;
  }

  public function clone():SongChartData
  {
    // We have to manually perform the deep clone here because Map.deepClone() doesn't work.
    var noteDataClone:Map<String, Array<SongNoteData>> = new Map<String, Array<SongNoteData>>();
    for (key in this.notes.keys())
    {
      noteDataClone.set(key, this.notes.get(key).deepClone());
    }
    var eventDataClone:Array<SongEventData> = this.events.deepClone();

    var result:SongChartData = new SongChartData(this.scrollSpeed.clone(), eventDataClone, noteDataClone);
    result.version = this.version;
    result.generatedBy = this.generatedBy;
    result.variation = this.variation;

    return result;
  }

  /**
   * Produces a string representation suitable for debugging.
   */
  public function toString():String
  {
    return 'SongChartData(${this.events.length} events, ${this.notes.size()} difficulties, ${generatedBy})';
  }
}

// (V-Slice's, for its classes and scripts)
/**
 * Offsets to apply to the song's instrumental and vocals, relative to the chart.
 * These are intended to correct for issues with the chart, or with the song's audio (for example a 10ms delay before the song starts).
 * This is independent of the offsets applied in the user's settings, which are applied after these offsets and intended to correct for the user's hardware.
 */
class SongOffsets implements ICloneable<SongOffsets>
{
  /**
   * The offset, in milliseconds, to apply to the song's instrumental relative to the chart.
   * For example, setting this to `-10.0` will start the instrumental 10ms earlier than the chart.
   *
   * Setting this to `-5000.0` means the chart start 5 seconds into the song.
   * Setting this to `5000.0` means there will be 5 seconds of silence before the song starts.
   */
  @:optional @:default(0)
  public var instrumental:Float;

  /**
   * Apply different offsets to different alternate instrumentals.
   */
  @:optional @:default([])
  public var altInstrumentals:Map<String, Float>;

  /**
   * The offset, in milliseconds, to apply to the song's vocals, relative to the song's base instrumental.
   * These are applied ON TOP OF the instrumental offset.
   */
  @:optional @:default([])
  public var vocals:Map<String, Float>;

  /**
   * The offset, in milliseconds, to apply to the songs vocals, relative to each alternate instrumental.
   * This is useful for the circumstance where, for example, an alt instrumental has a few seconds of lead in before the song starts.
   */
  @:optional @:default([])
  public var altVocals:Map<String, Map<String, Float>>;

  public function new(instrumental:Float = 0.0, ?altInstrumentals:Map<String, Float>, ?vocals:Map<String, Float>, ?altVocals:Map<String, Map<String, Float>>)
  {
    this.instrumental = instrumental;
    this.altInstrumentals = altInstrumentals == null ? new Map<String, Float>() : altInstrumentals;
    this.vocals = vocals == null ? new Map<String, Float>() : vocals;
    this.altVocals = altVocals == null ? new Map<String, Map<String, Float>>() : altVocals;
  }

  public function getInstrumentalOffset(?instrumental:String):Float
  {
    if (instrumental == null || instrumental == '') return this.instrumental;

    if (!this.altInstrumentals.exists(instrumental)) return this.instrumental;

    return this.altInstrumentals.get(instrumental);
  }

  public function setInstrumentalOffset(value:Float, ?instrumental:String):Float
  {
    if (instrumental == null || instrumental == '')
    {
      this.instrumental = value;
    }
    else
    {
      this.altInstrumentals.set(instrumental, value);
    }
    return value;
  }

  public function getVocalOffset(charId:String, ?instrumental:String):Float
  {
    if (instrumental == null)
    {
      if (!this.vocals.exists(charId)) return 0.0;
      return this.vocals.get(charId);
    }
    else
    {
      if (!this.altVocals.exists(instrumental)) return 0.0;
      if (!this.altVocals.get(instrumental).exists(charId)) return 0.0;
      return this.altVocals.get(instrumental).get(charId);
    }
  }

  public function setVocalOffset(charId:String, value:Float):Float
  {
    this.vocals.set(charId, value);
    return value;
  }

  public function clone():SongOffsets
  {
    var result:SongOffsets = new SongOffsets(this.instrumental);
    result.altInstrumentals = this.altInstrumentals.clone();
    result.vocals = this.vocals.clone();

    return result;
  }

  /**
   * Produces a string representation suitable for debugging.
   */
  public function toString():String
  {
    return 'SongOffsets(${this.instrumental}ms, ${this.altInstrumentals}, ${this.vocals}, ${this.altVocals})';
  }
}

// (V-Slice's, for its classes and scripts)
class NoteParamData implements ICloneable<NoteParamData>
{
  @:alias("n")
  public var name:String;
  @:alias("v")
  public var value:Dynamic;

  public function new(name:String, value:Dynamic)
  {
    this.name = name;
    this.value = value;
  }

  public function clone():NoteParamData
  {
    return new NoteParamData(this.name, this.value);
  }

  public function toString():String
  {
    return 'NoteParamData(${this.name}, ${this.value})';
  }
}
