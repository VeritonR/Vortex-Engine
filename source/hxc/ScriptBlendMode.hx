package hxc;

import openfl.display.BlendMode;

/**
 * `openfl.display.BlendMode` for scripts (`import openfl.display.BlendMode;`, `sprite.blend = BlendMode.ADD`). It's an abstract,
 * which scripts can't import as it is: these are its values, the same ones the game uses.
 */
@:keep
class ScriptBlendMode
{
	public static var ADD:BlendMode = BlendMode.ADD;
	public static var ALPHA:BlendMode = BlendMode.ALPHA;
	public static var DARKEN:BlendMode = BlendMode.DARKEN;
	public static var DIFFERENCE:BlendMode = BlendMode.DIFFERENCE;
	public static var ERASE:BlendMode = BlendMode.ERASE;
	public static var HARDLIGHT:BlendMode = BlendMode.HARDLIGHT;
	public static var INVERT:BlendMode = BlendMode.INVERT;
	public static var LAYER:BlendMode = BlendMode.LAYER;
	public static var LIGHTEN:BlendMode = BlendMode.LIGHTEN;
	public static var MULTIPLY:BlendMode = BlendMode.MULTIPLY;
	public static var NORMAL:BlendMode = BlendMode.NORMAL;
	public static var OVERLAY:BlendMode = BlendMode.OVERLAY;
	public static var SCREEN:BlendMode = BlendMode.SCREEN;
	public static var SHADER:BlendMode = BlendMode.SHADER;
	public static var SUBTRACT:BlendMode = BlendMode.SUBTRACT;

	public static function fromString(value:String):BlendMode
		return @:privateAccess BlendMode.fromString(value);
}
