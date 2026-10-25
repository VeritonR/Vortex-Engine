package funkin.util;

import flixel.FlxBasic;
import flixel.graphics.frames.FlxFrame;
import flixel.util.FlxSort;
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongData.SongNoteData;
import funkin.play.notes.NoteSprite;

/**
 * V-Slice's functions for sorting things, to be given to `sort()`.
 */
class SortUtil
{
	// The layer of something: a variable of everything on V-Slice, here only some classes have it and scripts keep it on the side for the rest
	static function getZIndex(object:FlxBasic):Float
	{
		var value:Dynamic = null;
		#if HSCRIPT_ALLOWED
		value = hxc.HxcRuntime.getValue(object, 'zIndex');
		#else
		try
		{
			value = Reflect.getProperty(object, 'zIndex');
		}
		catch(e:Dynamic) {}
		#end
		return Std.isOfType(value, Float) ? value : 0;
	}

	/**
	 * By layer, for groups: `group.sort(SortUtil.byZIndex, FlxSort.ASCENDING)`.
	 */
	public static function byZIndex(order:Int, a:FlxBasic, b:FlxBasic):Int
	{
		if(a == null && b == null) return 0;
		if(a == null) return order;
		if(b == null) return -order;
		return FlxSort.byValues(order, getZIndex(a), getZIndex(b));
	}

	public static function byStrumtime(order:Int, a:NoteSprite, b:NoteSprite):Int
	{
		return FlxSort.byValues(order, a.strumTime, b.strumTime);
	}

	public static function noteDataByTime(order:Int, a:SongNoteData, b:SongNoteData):Int
	{
		return FlxSort.byValues(order, a.time, b.time);
	}

	public static function eventDataByTime(order:Int, a:SongEventData, b:SongEventData):Int
	{
		return FlxSort.byValues(order, a.time, b.time);
	}

	public static function byFrameName(a:FlxFrame, b:FlxFrame):Int
	{
		return alphabetically(a.name, b.name);
	}

	public static function alphabetically(a:String, b:String):Int
	{
		a = a.toUpperCase();
		b = b.toUpperCase();
		return (a == b) ? 0 : ((a > b) ? 1 : -1);
	}

	/**
	 * Alphabetically, with one value before everything else.
	 */
	public static function defaultThenAlphabetically(defaultValue:String, a:String, b:String):Int
	{
		if(a == b) return 0;
		if(a == defaultValue) return -1;
		if(b == defaultValue) return 1;
		return alphabetically(a, b);
	}

	/**
	 * Alphabetically, with some values before everything else in the order they were given.
	 */
	public static function defaultsThenAlphabetically(defaultValues:Array<String>, a:String, b:String):Int
	{
		if(a == b) return 0;
		if(defaultValues.contains(a) && defaultValues.contains(b)) return defaultValues.indexOf(a) - defaultValues.indexOf(b);
		if(defaultValues.contains(a)) return -1;
		if(defaultValues.contains(b)) return 1;
		return alphabetically(a, b);
	}
}
