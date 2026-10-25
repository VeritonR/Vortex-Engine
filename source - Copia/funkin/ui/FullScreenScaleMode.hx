package funkin.ui;

import flixel.util.FlxAxes;

/**
 * V-Slice's way of filling screens that are wider than the game (phones), which scripts ask about to place their things.
 * The engine's screen is always the game's own size: there are no cutouts and nothing is scaled.
 */
class FullScreenScaleMode
{
	public static var cutoutSize:FlxPoint = FlxPoint.get(0, 0);
	public static var notchPosition:FlxPoint = FlxPoint.get(0, 0);
	public static var notchSize:FlxPoint = FlxPoint.get(0, 0);
	public static var logicalSize:FlxPoint = FlxPoint.get(0, 0);
	public static var maxAspectRatio:FlxPoint = FlxPoint.get(20, 9);
	public static var maxRatioAxis:FlxAxes = X;
	public static var gameRatio:Float = 16 / 9;
	public static var gameCutoutSize:FlxPoint = FlxPoint.get(0, 0);
	public static var gameNotchPosition:FlxPoint = FlxPoint.get(0, 0);
	public static var gameNotchSize:FlxPoint = FlxPoint.get(0, 0);
	public static var screenRatio:Float = 16 / 9;
	public static var wideScale:FlxPoint = FlxPoint.get(1, 1);
	public static var ratioAxis:FlxAxes = X;
	public static var instance:FullScreenScaleMode = null;
	public static var enabled:Bool = false;
	public static var hasFakeCutouts:Bool = false;

	public static function addCutouts(tweenDuration:Float = 0.0, ?ease:Float->Float):Void {}
	public static function removeCutouts(tweenDuration:Float = 0.0, ?ease:Float->Float):Void {}
}
