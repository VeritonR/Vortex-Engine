package funkin.util;

import flixel.FlxBasic;
import flixel.FlxObject;

/**
 * V-Slice's touch screen input, which is the mouse when there's no touch screen. Scripts use it for what's tapped on phones (the pause button and such).
 */
class TouchUtil
{
	public static var pressed(get, never):Bool;
	static function get_pressed():Bool return FlxG.mouse.pressed;

	public static var justPressed(get, never):Bool;
	static function get_justPressed():Bool return FlxG.mouse.justPressed;

	public static var justReleased(get, never):Bool;
	static function get_justReleased():Bool return FlxG.mouse.justReleased;

	public static var released(get, never):Bool;
	static function get_released():Bool return FlxG.mouse.released;

	public static var justMoved(get, never):Bool;
	static function get_justMoved():Bool return FlxG.mouse.justMoved;

	public static var touch(get, never):flixel.input.mouse.FlxMouse;
	static function get_touch():flixel.input.mouse.FlxMouse return FlxG.mouse;

	public static function overlaps(?object:FlxBasic, ?camera:FlxCamera):Bool
	{
		return object != null && FlxG.mouse.overlaps(object, camera);
	}

	public static function overlapsComplex(?object:FlxObject, ?camera:FlxCamera):Bool
	{
		return object != null && FlxG.mouse.overlaps(object, camera);
	}

	public static function overlapsComplexPoint(?object:FlxObject, point:FlxPoint, ?inScreenSpace:Bool = false, ?camera:FlxCamera):Bool
	{
		return object != null && point != null && object.overlapsPoint(point, inScreenSpace, camera);
	}

	public static function pressAction(?object:FlxBasic, ?camera:FlxCamera, useOverlapsComplex:Bool = true):Bool
	{
		return justReleased && overlaps(object, camera);
	}
}
