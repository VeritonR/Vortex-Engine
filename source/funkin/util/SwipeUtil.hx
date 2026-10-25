package funkin.util;

/**
 * V-Slice's swipes on a touch screen. There are none on this engine's platforms: nothing is ever swiped.
 */
class SwipeUtil
{
	public static var swipeUp(default, never):Bool = false;
	public static var swipeRight(default, never):Bool = false;
	public static var swipeLeft(default, never):Bool = false;
	public static var swipeDown(default, never):Bool = false;
	public static var swipeAny(default, never):Bool = false;
	public static var justSwipedUp(default, never):Bool = false;
	public static var justSwipedRight(default, never):Bool = false;
	public static var justSwipedLeft(default, never):Bool = false;
	public static var justSwipedDown(default, never):Bool = false;
	public static var justSwipedAny(default, never):Bool = false;
	public static var flickUp(default, never):Bool = false;
	public static var flickRight(default, never):Bool = false;
	public static var flickLeft(default, never):Bool = false;
	public static var flickDown(default, never):Bool = false;
	public static var flickAny(default, never):Bool = false;

	public static function calculateSwipeThreshold(items:Array<Dynamic>, axes:Dynamic, ?multiplier:Float = 1):Void {}
	public static function resetSwipeVelocity():Void {}
}
