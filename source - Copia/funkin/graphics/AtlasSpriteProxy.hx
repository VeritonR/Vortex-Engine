package funkin.graphics;

import flxanimate.animate.FlxElement;
import objects.AtlasSprite;

#if HSCRIPT_ALLOWED
import hxc.HxcInstance;
import hxc.HxcRuntime.IHxcScripted;
#end

/**
 * What a script class that extends `FunkinSprite` to be a texture atlas really is here (like the animations of the results screen):
 * on V-Slice every sprite can be one, here they're a class of their own (`objects.AtlasSprite`).
 *
 * This gives the script the names V-Slice has for things: `loadTextureAtlas()`, `anim` and `animation` with their signals,
 * `getFirstElement()`, `scaleElement()`... and passes everything on to the real sprite, which is what the engine puts on the screen.
 */
class AtlasSpriteProxy #if HSCRIPT_ALLOWED implements IHxcScripted #end
{
	#if HSCRIPT_ALLOWED
	public var __hxc:HxcInstance = null;
	#end

	/**
	 * The sprite itself.
	 */
	public var sprite(default, null):AtlasSprite;

	public function new(x:Float = 0, y:Float = 0)
	{
		sprite = new AtlasSprite(x, y);
	}

	// ------------------------------------------------------------------------------------------
	// Animations
	// ------------------------------------------------------------------------------------------

	public var anim(get, never):AtlasPlayer;
	function get_anim():AtlasPlayer return sprite.player;

	public var animation(get, never):AtlasPlayer;
	function get_animation():AtlasPlayer return sprite.player;

	public function loadTextureAtlas(path:String, ?library:String, ?settings:Dynamic):AtlasSpriteProxy
	{
		sprite.loadTextureAtlas(path, library, settings);
		return this;
	}

	public function playAnimation(name:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false):Void
	{
		sprite.player.play(name, restart, reversed);
	}

	public function hasAnimation(name:String):Bool return sprite.player.exists(name);
	public function getCurrentAnimation():String return sprite.player.name;
	public function isAnimationFinished():Bool return sprite.player.finished;

	public function getSymbolElements(symbol:String):Array<FlxElement> return sprite.getSymbolElements(symbol);
	public function getFirstElement(symbol:String):FlxElement return sprite.getFirstElement(symbol);

	public function scaleElement(element:FlxElement, scale:Float, positionOffset:Float = 0, scaleEverything:Bool = false):Void
	{
		sprite.scaleElement(element, scale, positionOffset, scaleEverything);
	}

	// ------------------------------------------------------------------------------------------
	// What every sprite has
	// ------------------------------------------------------------------------------------------

	public var x(get, set):Float;
	function get_x():Float return sprite.x;
	function set_x(value:Float):Float return sprite.x = value;

	public var y(get, set):Float;
	function get_y():Float return sprite.y;
	function set_y(value:Float):Float return sprite.y = value;

	public var alpha(get, set):Float;
	function get_alpha():Float return sprite.alpha;
	function set_alpha(value:Float):Float return sprite.alpha = value;

	public var angle(get, set):Float;
	function get_angle():Float return sprite.angle;
	function set_angle(value:Float):Float return sprite.angle = value;

	public var visible(get, set):Bool;
	function get_visible():Bool return sprite.visible;
	function set_visible(value:Bool):Bool return sprite.visible = value;

	public var active(get, set):Bool;
	function get_active():Bool return sprite.active;
	function set_active(value:Bool):Bool return sprite.active = value;

	public var antialiasing(get, set):Bool;
	function get_antialiasing():Bool return sprite.antialiasing;
	function set_antialiasing(value:Bool):Bool return sprite.antialiasing = value;

	public var flipX(get, set):Bool;
	function get_flipX():Bool return sprite.flipX;
	function set_flipX(value:Bool):Bool return sprite.flipX = value;

	public var flipY(get, set):Bool;
	function get_flipY():Bool return sprite.flipY;
	function set_flipY(value:Bool):Bool return sprite.flipY = value;

	public var color(get, set):FlxColor;
	function get_color():FlxColor return sprite.color;
	function set_color(value:FlxColor):FlxColor return sprite.color = value;

	public var zIndex(get, set):Int;
	function get_zIndex():Int return sprite.zIndex;
	function set_zIndex(value:Int):Int return sprite.zIndex = value;

	public var shader(get, set):Dynamic;
	function get_shader():Dynamic return sprite.shader;
	function set_shader(value:Dynamic):Dynamic return sprite.shader = value;

	public var blend(get, set):Dynamic;
	function get_blend():Dynamic return sprite.blend;
	function set_blend(value:Dynamic):Dynamic return sprite.blend = value;

	public var cameras(get, set):Array<FlxCamera>;
	function get_cameras():Array<FlxCamera> return sprite.cameras;
	function set_cameras(value:Array<FlxCamera>):Array<FlxCamera> return sprite.cameras = value;

	public var scale(get, never):FlxPoint;
	function get_scale():FlxPoint return sprite.scale;

	public var scrollFactor(get, never):FlxPoint;
	function get_scrollFactor():FlxPoint return sprite.scrollFactor;

	public var width(get, never):Float;
	function get_width():Float return sprite.width;

	public var height(get, never):Float;
	function get_height():Float return sprite.height;

	public var alive(get, never):Bool;
	function get_alive():Bool return sprite.alive;

	public var exists(get, never):Bool;
	function get_exists():Bool return sprite.exists;

	public function setPosition(x:Float = 0, y:Float = 0):Void sprite.setPosition(x, y);
	public function screenCenter():Void sprite.screenCenter();
	public function updateHitbox():Void {}
	public function kill():Void sprite.kill();
	public function revive():Void sprite.revive();
	public function destroy():Void sprite.destroy();

	public function toString():String
	{
		return 'AtlasSprite';
	}
}
