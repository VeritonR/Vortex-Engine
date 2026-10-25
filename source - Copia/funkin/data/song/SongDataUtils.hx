package funkin.data.song;

/**
 * V-Slice's helpers for a song's data, the ones scripts use. Time changes, notes and events are sorted by their time
 * (`timeStamp` on time changes, `time` on the others; their names on the chart, `t`, are read too).
 */
class SongDataUtils
{
	public static function sortTimeChanges(timeChanges:Array<Dynamic>, desc:Bool = false):Array<Dynamic>
	{
		if(timeChanges != null) timeChanges.sort((a, b) -> compare(timeOf(a, 'timeStamp'), timeOf(b, 'timeStamp'), desc));
		return timeChanges;
	}

	public static function sortNotes(notes:Array<Dynamic>, desc:Bool = false):Array<Dynamic>
	{
		if(notes != null) notes.sort((a, b) -> compare(timeOf(a, 'time'), timeOf(b, 'time'), desc));
		return notes;
	}

	public static function sortEvents(events:Array<Dynamic>, desc:Bool = false):Array<Dynamic>
	{
		if(events != null) events.sort((a, b) -> compare(timeOf(a, 'time'), timeOf(b, 'time'), desc));
		return events;
	}

	static function timeOf(item:Dynamic, name:String):Float
	{
		if(item == null) return 0;
		var value:Dynamic = Reflect.getProperty(item, name);
		if(value == null) value = Reflect.field(item, 't');
		return (value != null) ? value : 0;
	}

	static inline function compare(a:Float, b:Float, desc:Bool):Int
	{
		var result:Int = (a < b) ? -1 : ((a > b) ? 1 : 0);
		return desc ? -result : result;
	}
}
