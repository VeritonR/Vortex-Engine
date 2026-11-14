package funkin.util;

import flixel.FlxBasic;
import flixel.FlxObject;
#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end

/**
 * V-Slice's touch screen input, which is the mouse when there's no touch screen. Scripts use it for what's tapped on phones (the
 * pause button, a mod's popups to click...). Like V-Slice's, it's any of the fingers on the screen: the mouse of a phone is only
 * one of them (see backend.TouchMouse), and a player holding the arrows with one taps with another.
 */
class TouchUtil
{
	public static var pressed(get, never):Bool;
	static function get_pressed():Bool return anyTouch(function(touch) return touch.pressed) || FlxG.mouse.pressed;

	public static var justPressed(get, never):Bool;
	static function get_justPressed():Bool return anyTouch(function(touch) return touch.justPressed) || FlxG.mouse.justPressed;

	public static var justReleased(get, never):Bool;
	static function get_justReleased():Bool return anyTouch(function(touch) return touch.justReleased) || FlxG.mouse.justReleased;

	public static var released(get, never):Bool;
	static function get_released():Bool return !pressed;

	public static var justMoved(get, never):Bool;
	static function get_justMoved():Bool return anyTouch(function(touch) return touch.justMoved) || FlxG.mouse.justMoved;

	public static var touch(get, never):flixel.input.mouse.FlxMouse;
	static function get_touch():flixel.input.mouse.FlxMouse return FlxG.mouse;

	public static function overlaps(?object:FlxBasic, ?camera:FlxCamera):Bool
	{
		if(object == null) return false;
		return anyTouch(function(touch) return touch.overlaps(object, camera)) || FlxG.mouse.overlaps(object, camera);
	}

	public static function overlapsComplex(?object:FlxObject, ?camera:FlxCamera):Bool
	{
		if(object == null) return false;
		if(camera == null) camera = (object.cameras != null && object.cameras.length > 0) ? object.cameras[0] : FlxG.camera;
		return anyTouch(function(touch) return object.overlapsPoint(touch.getWorldPosition(camera), true, camera)) || FlxG.mouse.overlaps(object, camera);
	}

	public static function overlapsComplexPoint(?object:FlxObject, point:FlxPoint, ?inScreenSpace:Bool = false, ?camera:FlxCamera):Bool
	{
		return object != null && point != null && object.overlapsPoint(point, inScreenSpace, camera);
	}

	public static function pressAction(?object:FlxBasic, ?camera:FlxCamera, useOverlapsComplex:Bool = true):Bool
	{
		if(object == null) return false;
		#if FLX_TOUCH
		if(FlxG.touches != null)
			for (touch in FlxG.touches.list)
				if(touch != null && touch.justReleased && touch.overlaps(object, camera)) return true;
		#end
		return FlxG.mouse.justReleased && FlxG.mouse.overlaps(object, camera);
	}

	// (if one of the fingers on the screen is like that)
	static function anyTouch(test:Dynamic->Bool):Bool
	{
		#if FLX_TOUCH
		if(FlxG.touches != null)
			for (touch in FlxG.touches.list)
				if(touch != null && test(touch)) return true;
		#end
		return false;
	}
}
