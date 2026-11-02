package backend;

import flixel.input.keyboard.FlxKey;

/**
 * Songs with another number of arrows than 4 (1 to 9 per side), like Shaggy's 6 and 9 key songs.
 *
 * A song says how many with `"keyCount": 6` in its chart (Psych Engine Extra Keys' `"mania"` is read too: its number plus one).
 * The chart's notes are then 0 to keyCount-1 on one side and keyCount to keyCount*2-1 on the other, like Psych's 0-3 and 4-7.
 *
 * Each column is drawn with one of the 4 arrows (or the middle one, drawn with the up arrow), colored as the arrow of its place:
 * a second arrow of the same direction gets another color (6 keys: purple, green, red, yellow, blue, dark blue). The arrows get
 * smaller the more there are, and the keys are set in Options > More > Extra Keys (S D F J K L for 6 keys...).
 */
class ExtraKeys
{
	public static inline var MIN:Int = 1;
	public static inline var MAX:Int = 9;

	/**
	 * The number of arrows of each side in the song being played (or charted): 4 everywhere else.
	 */
	public static var keyCount(default, null):Int = 4;

	// 0 left, 1 down, 2 up, 3 right, 4 the middle one (a "space" key)
	public static final LAYOUTS:Array<Array<Int>> = [
		[],
		[4],
		[0, 3],
		[0, 4, 3],
		[0, 1, 2, 3],
		[0, 1, 4, 2, 3],
		[0, 2, 3, 0, 1, 3],
		[0, 2, 3, 4, 0, 1, 3],
		[0, 1, 2, 3, 0, 1, 2, 3],
		[0, 1, 2, 3, 4, 0, 1, 2, 3]
	];

	// how big the arrows are, by how many there are
	static final SCALES:Array<Float> = [1, 1, 1, 1, 1, 0.9, 0.8, 0.7, 0.62, 0.56];

	public static final DEFAULT_KEYS:Array<Array<FlxKey>> = [
		[],
		[SPACE],
		[F, J],
		[F, SPACE, J],
		[], //(4 keys: the usual note keys)
		[D, F, SPACE, J, K],
		[S, D, F, J, K, L],
		[S, D, F, SPACE, J, K, L],
		[A, S, D, F, H, J, K, L],
		[A, S, D, F, SPACE, H, J, K, L]
	];

	// the colors of a second arrow of the same direction (fill, light, outline), and of the middle one
	static final SECOND_COLORS:Array<Array<FlxColor>> = [
		[0xFFE8C400, 0xFFFFFFFF, 0xFF6B4A00], //left: yellow
		[0xFF9B3FE0, 0xFFFFFFFF, 0xFF3A1060], //down: violet
		[0xFFB31D3A, 0xFFFFFFFF, 0xFF4A0011], //up: dark red
		[0xFF2847D9, 0xFFFFFFFF, 0xFF0B1A5C]  //right: dark blue
	];
	static final MIDDLE_COLOR:Array<FlxColor> = [0xFFD8D8D8, 0xFFFFFFFF, 0xFF4A4A4A];

	static var listening:Bool = false;

	/**
	 * Back to 4 on every screen change: the screens with notes of their own (a song, the chart editor) set theirs when they're made.
	 */
	public static function init():Void
	{
		if(listening) return;
		listening = true;
		FlxG.signals.preStateSwitch.add(function() setKeyCount(4));
	}

	/**
	 * How many arrows a song has: its "keyCount", or Extra Keys' "mania" plus one, or 4.
	 */
	public static function countOf(song:Dynamic):Int
	{
		if(song == null) return 4;
		var count:Dynamic = Reflect.field(song, 'keyCount');
		if(count == null)
		{
			var mania:Dynamic = Reflect.field(song, 'mania');
			if(mania != null && Std.parseInt(Std.string(mania)) != null) count = Std.parseInt(Std.string(mania)) + 1;
		}
		var number:Null<Int> = (count != null) ? Std.parseInt(Std.string(count)) : null;
		return (number == null) ? 4 : Std.int(FlxMath.bound(number, MIN, MAX));
	}

	public static function setKeyCount(count:Int):Void
	{
		count = Std.int(FlxMath.bound(count, MIN, MAX));
		if(count == keyCount) return;
		keyCount = count;
		objects.Note.swagWidth = 160 * 0.7 * scale();
		objects.Note.globalRgbShaders = []; //(their colors are by column)
	}

	/**
	 * How big the arrows are compared to 4 keys.
	 */
	public static inline function scale():Float
		return SCALES[keyCount];

	/**
	 * What a column looks like: 0 left, 1 down, 2 up, 3 right, 4 the middle one.
	 */
	public static function shapeOf(column:Int):Int
	{
		if(column < 0) return 0;
		var layout:Array<Int> = LAYOUTS[keyCount];
		return layout[column % layout.length];
	}

	/**
	 * The arrow a column is drawn with, and the animation it makes characters sing: 0 left, 1 down, 2 up (the middle one too), 3 right.
	 */
	public static function animShape(column:Int):Int
	{
		var shape:Int = shapeOf(column);
		return (shape == 4) ? 2 : shape;
	}

	/**
	 * The colors of a column (fill, light, outline), from the ones set in Note Colors for its direction.
	 */
	public static function rgbOf(column:Int, ?pixel:Bool = false):Array<FlxColor>
	{
		var source:Array<Array<FlxColor>> = pixel ? ClientPrefs.data.arrowRGBPixel : ClientPrefs.data.arrowRGB;
		if(keyCount == 4) return source[((column % 4) + 4) % 4];

		var shape:Int = shapeOf(column);
		if(shape == 4) return MIDDLE_COLOR;
		// (the first arrow of a direction has its own color, the next one of the same direction the second color)
		var layout:Array<Int> = LAYOUTS[keyCount];
		var place:Int = column % layout.length;
		for (i in 0...place) if(layout[i] == shape) return SECOND_COLORS[shape];
		return source[shape];
	}

	/**
	 * How far the arrows of a side are moved so that they're centered where 4 would be.
	 */
	public static function sideShift():Float
		return (4 * 160 * 0.7 - keyCount * objects.Note.swagWidth) / 2;

	/**
	 * The names of the keys of each column (in the Controls' list): "note_left"... for 4, "ek6_0"... for the others.
	 */
	public static function actions(?count:Null<Int>):Array<String>
	{
		if(count == null) count = keyCount;
		if(count == 4) return ['note_left', 'note_down', 'note_up', 'note_right'];
		return [for (i in 0...count) 'ek${count}_$i'];
	}

	/**
	 * The default keys of every number of arrows, put in the game's list of keys (see ClientPrefs.keyBinds), so they're saved with the others.
	 */
	public static function addDefaultBinds(keyBinds:Map<String, Array<FlxKey>>):Void
	{
		for (count in MIN...MAX + 1)
		{
			if(count == 4) continue;
			for (i => action in actions(count))
				if(!keyBinds.exists(action)) keyBinds.set(action, [DEFAULT_KEYS[count][i]]);
		}
	}
}
