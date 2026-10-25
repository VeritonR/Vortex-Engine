package funkin.util;

/**
 * flixel's kinds of tweens (`FlxTweenType.PINGPONG`) for scripts: an enum of numbers, which scripts can't import as it is.
 */
class ScriptTweenType
{
	public static var PERSIST:Int = 1;
	public static var LOOPING:Int = 2;
	public static var PINGPONG:Int = 4;
	public static var ONESHOT:Int = 8;
	public static var BACKWARD:Int = 16;
}
