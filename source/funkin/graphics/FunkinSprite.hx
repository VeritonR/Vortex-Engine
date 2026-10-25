package funkin.graphics;

import flixel.graphics.FlxGraphic;

#if HSCRIPT_ALLOWED
import hxc.HxcInstance;
import hxc.HxcRuntime.IHxcScripted;
#end

/**
 * V-Slice's sprite class: a regular sprite with a layer and shortcuts to load things.
 *
 * Scripts can also extend it (`class MySprite extends FunkinSprite`), what they override of `update`, `draw`, `destroy`, `kill` and `revive`
 * is run by the engine like on a real class.
 */
class FunkinSprite extends FlxSprite #if HSCRIPT_ALLOWED implements IHxcScripted #end
{
	#if HSCRIPT_ALLOWED
	public var __hxc:HxcInstance = null;
	#end

	/**
	 * Layer on the stage: `Stage.add()` puts the sprite behind the characters that have a bigger one.
	 */
	public var zIndex:Int = 0;

	/**
	 * @param simpleGraphic 	An image for the sprite, like the regular ones take: what `Paths.image()` gives.
	 */
	public function new(?x:Float = 0, ?y:Float = 0, ?simpleGraphic:Dynamic)
	{
		super(x, y);
		antialiasing = ClientPrefs.data.antialiasing;

		if(Std.isOfType(simpleGraphic, FlxGraphic) || Std.isOfType(simpleGraphic, openfl.display.BitmapData)) loadGraphic(simpleGraphic);
		else if(Std.isOfType(simpleGraphic, String)) loadTexture(simpleGraphic);
	}

	// ------------------------------------------------------------------------------------------
	// Making and loading
	// ------------------------------------------------------------------------------------------

	public static function create(x:Float = 0, y:Float = 0, key:String):FunkinSprite
	{
		var sprite:FunkinSprite = new FunkinSprite(x, y);
		sprite.loadTexture(key);
		return sprite;
	}

	/**
	 * Makes a texture atlas, out of its folder inside the images folder. They're a class of their own here: see `objects.AtlasSprite`.
	 */
	public static function createTextureAtlas(x:Float = 0, y:Float = 0, path:String, ?library:String, ?settings:Dynamic):objects.AtlasSprite
	{
		var sprite:objects.AtlasSprite = new objects.AtlasSprite(x, y);
		sprite.loadTextureAtlas(path, library, settings);
		return sprite;
	}

	public static function createSparrow(x:Float = 0, y:Float = 0, key:String):FunkinSprite
	{
		var sprite:FunkinSprite = new FunkinSprite(x, y);
		sprite.loadSparrow(key);
		return sprite;
	}

	public static function createPacker(x:Float = 0, y:Float = 0, key:String):FunkinSprite
	{
		var sprite:FunkinSprite = new FunkinSprite(x, y);
		sprite.loadPacker(key);
		return sprite;
	}

	public function loadTexture(key:String):FunkinSprite
	{
		var graphic:FlxGraphic = funkin.Paths.image(key);
		if(graphic != null) loadGraphic(graphic);
		return this;
	}

	public function loadSparrow(key:String):FunkinSprite
	{
		var sparrow = funkin.Paths.getSparrowAtlas(key);
		if(sparrow != null) frames = sparrow;
		return this;
	}

	public function loadPacker(key:String):FunkinSprite
	{
		var packer = funkin.Paths.getPackerAtlas(key);
		if(packer != null) frames = packer;
		return this;
	}

	// ------------------------------------------------------------------------------------------
	// Texture atlases
	// ------------------------------------------------------------------------------------------

	/**
	 * The texture atlas the sprite shows, once it loaded one. On V-Slice any sprite can be a texture atlas; here those are a class of their own
	 * (`objects.AtlasSprite`), which this sprite keeps and draws in its place, where it is and with its scale, colors, shader and the rest.
	 * To scripts its animations are the sprite's own `animation` and `anim` (see backend.VSliceScripts.setupRuntime()).
	 */
	public var atlas(default, null):objects.AtlasSprite = null;

	/**
	 * If the texture atlas is drawn whole on a texture of its own before going on the screen (see `PsychFlxAnimate.useRenderTexture`).
	 * One of V-Slice's atlas settings, which its scripts and its shaders also turn on by themselves.
	 */
	public var useRenderTexture:Bool = false;

	// Size of what the atlas shows, without the sprite's scale
	var atlasWidth:Float = 0;
	var atlasHeight:Float = 0;

	/**
	 * What plays the sprite's animations. V-Slice's sprites have it under this name as well.
	 */
	public var anim(get, never):Dynamic;
	function get_anim():Dynamic return (atlas != null) ? atlas.player : animation;

	/**
	 * Makes the sprite a texture atlas, out of its folder inside of the images one.
	 */
	public function loadTextureAtlas(path:String, ?library:String, ?settings:Dynamic):FunkinSprite
	{
		if(path == null) return this;

		if(atlas == null) atlas = new objects.AtlasSprite();
		atlas.loadTextureAtlas(path, library, settings);
		if(settings != null && Reflect.field(settings, 'useRenderTexture') == true) useRenderTexture = true;
		if(atlas.loaded)
		{
			atlasWidth = atlas.width;
			atlasHeight = atlas.height;
			updateHitbox();
		}
		return this;
	}

	/**
	 * Name of the main symbol of the sprite's texture atlas, the one that has its whole timeline.
	 */
	public function getDefaultSymbol():String
	{
		return (atlas != null) ? atlas.defaultSymbol : '';
	}

	override function updateHitbox():Void
	{
		if(atlas == null || !atlas.loaded)
		{
			super.updateHitbox();
			return;
		}

		// the same a regular sprite does, with the size of what the atlas shows as its frame
		width = Math.abs(scale.x) * atlasWidth;
		height = Math.abs(scale.y) * atlasHeight;

		// (the ones placed like on their file grow from the sprite's position, there's nothing to make up for)
		if(atlas.applyStageMatrix) offset.set(0, 0);
		else offset.set(-0.5 * (width - atlasWidth), -0.5 * (height - atlasHeight));
	}

	function drawAtlas():Void
	{
		if(!atlas.loaded) return;

		atlas.x = x - offset.x;
		atlas.y = y - offset.y;
		atlas.scale.copyFrom(scale);
		atlas.scrollFactor.copyFrom(scrollFactor);
		atlas.angle = angle;
		atlas.alpha = alpha;
		atlas.color = color;
		atlas.flipX = flipX;
		atlas.flipY = flipY;
		atlas.shader = shader;
		atlas.useRenderTexture = useRenderTexture;
		atlas.blend = blend;
		atlas.antialiasing = antialiasing;
		@:privateAccess atlas._cameras = _cameras;
		atlas.draw();
	}

	public function makeSolidColor(width:Int, height:Int, color:FlxColor = FlxColor.WHITE):FunkinSprite
	{
		makeGraphic(1, 1, color);
		scale.set(width, height);
		updateHitbox();
		return this;
	}

	// ------------------------------------------------------------------------------------------
	// Animations
	// ------------------------------------------------------------------------------------------

	public function hasAnimation(name:String):Bool
	{
		return (atlas != null) ? atlas.player.exists(name) : animation.exists(name);
	}

	public function getCurrentAnimation():String
	{
		if(atlas != null) return atlas.player.name;
		return (animation.curAnim != null) ? animation.curAnim.name : '';
	}

	public function isAnimationFinished():Bool
	{
		if(atlas != null) return atlas.player.finished;
		return animation.curAnim == null || animation.curAnim.finished;
	}

	public function playAnimation(name:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false):Void
	{
		if(atlas != null)
		{
			if(atlas.player.exists(name)) atlas.player.play(name, restart, reversed);
		}
		else if(animation.exists(name)) animation.play(name, restart, reversed);
	}

	// ------------------------------------------------------------------------------------------
	// What scripts can override
	// ------------------------------------------------------------------------------------------

	// Runs the script's version of a function, returns false if there's no script or it doesn't have one
	function callScript(name:String, ?args:Array<Dynamic>):Bool
	{
		#if HSCRIPT_ALLOWED
		if(__hxc != null && __hxc.hasMethod(name) && !__hxc.inSuperCall(name))
		{
			__hxc.call(name, args);
			return true;
		}
		#end
		return false;
	}

	override function update(elapsed:Float):Void
	{
		if(!callScript('update', [elapsed])) __super_update(elapsed);
	}

	override function draw():Void
	{
		if(!callScript('draw')) __super_draw();
	}

	override function destroy():Void
	{
		if(!callScript('destroy')) __super_destroy();
	}

	override function kill():Void
	{
		if(!callScript('kill')) super.kill();
	}

	override function revive():Void
	{
		if(!callScript('revive')) super.revive();
	}

	// What `super.update(elapsed)` and the others run when called from a script
	public function __super_update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(atlas != null) atlas.update(elapsed);
	}

	public function __super_draw():Void
	{
		if(atlas != null) drawAtlas();
		else super.draw();
	}

	public function __super_destroy():Void
	{
		atlas = flixel.util.FlxDestroyUtil.destroy(atlas);
		super.destroy();
	}
	public function __super_kill():Void super.kill();
	public function __super_revive():Void super.revive();

	// ------------------------------------------------------------------------------------------
	// More of V-Slice's functions
	// ------------------------------------------------------------------------------------------

	public function getDefaultAtlasSettings():Dynamic
	{
		return {swfMode: false, cacheOnLoad: false, filterQuality: 1, applyStageMatrix: false, useRenderTexture: false};
	}

	public function getSymbolElements(symbol:String):Array<Dynamic>
	{
		return (atlas != null) ? cast atlas.getSymbolElements(symbol) : [];
	}

	public function getFirstElement(symbol:String):Dynamic
	{
		return (atlas != null) ? atlas.getFirstElement(symbol) : null;
	}

	public function scaleElement(element:Dynamic, scale:Float, positionOffset:Float = 0, scaleEverything:Bool = false):Void
	{
		if(atlas != null && element != null) atlas.scaleElement(element, scale, positionOffset, scaleEverything);
	}

	// The frames of the atlas' symbols with something on their name, for things to be put on them (see `SpriteElement`)
	public function getFramesWithKeyword(keyword:String):Array<Dynamic>
	{
		return (atlas != null) ? cast atlas.getFramesWithKeyword(keyword) : [];
	}

	public function replaceSymbolGraphic(symbol:String, graphic:Dynamic, ?adjustScale:Bool):Void {}

	public function getFrameLabelList():Array<String>
	{
		return (atlas != null) ? atlas.player.getFrameLabelNames() : [];
	}

	public function listAnimations():Array<String>
	{
		if(atlas != null) return atlas.player.getNameList();
		return (animation != null) ? animation.getNameList() : [];
	}

	public function isAnimationDynamic(id:String):Bool
	{
		if(atlas != null) return atlas.player.hasAnimation(id);

		var data = (animation != null) ? animation.getByName(id) : null;
		return data != null && data.numFrames > 1;
	}

	/**
	 * An image that's already loaded as what the sprite shows.
	 */
	public function loadBitmapData(input:openfl.display.BitmapData, cache:Bool = true):FunkinSprite
	{
		if(input != null) loadGraphic(flixel.graphics.FlxGraphic.fromBitmapData(input, false, null, cache));
		return this;
	}

	// (V-Slice loads it on another thread and shows it when it's ready, here it's there right away)
	public function loadTextureAsync(key:String, fade:Bool = false):Void
	{
		loadTexture(key);
		if(fade)
		{
			alpha = 0;
			FlxTween.tween(this, {alpha: 1}, 0.25);
		}
	}
}
