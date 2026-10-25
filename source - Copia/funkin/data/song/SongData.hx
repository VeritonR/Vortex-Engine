package funkin.data.song;

/**
 * Only here so `funkin.data.song.SongData.SongEventData` and the like lead to the classes below, like on V-Slice.
 */
class SongData {}

/**
 * A change of tempo of a V-Slice song (`timeChanges` of its metadata: "t", "b", "bpm", "n", "d" there).
 */
class SongTimeChange
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

	public function toString():String return 'SongTimeChange($timeStamp ms, $bpm bpm)';
}

/**
 * An event of a V-Slice chart, as scripts get it.
 */
class SongEventData
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
class SongNoteData
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

	public function toString():String
	{
		return 'SongNoteData($time ms, $data' + ((kind != null && kind.length > 0) ? ', $kind)' : ')');
	}
}
