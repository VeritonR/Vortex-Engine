package funkin.util.assets;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxFramesCollection;

/**
 * V-Slice's helpers to add animations from their data (`{name, prefix, frameRate, looped, frameIndices, flipX, flipY, animType}`).
 */
class FlxAnimationUtil
{
	public static function addAtlasAnimation(target:FlxSprite, anim:Dynamic):Void
	{
		if(target == null || anim == null || anim.prefix == null) return;

		var frameRate:Int = (anim.frameRate != null) ? anim.frameRate : 24;
		var looped:Bool = anim.looped == true;
		var flipX:Bool = anim.flipX == true;
		var flipY:Bool = anim.flipY == true;
		var indices:Array<Int> = anim.frameIndices;

		if(indices != null && indices.length > 0) target.animation.addByIndices(anim.name, anim.prefix, indices, '', frameRate, looped, flipX, flipY);
		else target.animation.addByPrefix(anim.name, anim.prefix, frameRate, looped, flipX, flipY);
	}

	/**
	 * For a sprite that's a texture atlas: by the frame labels of its timeline, or by its symbols with `animType: "symbol"`.
	 */
	public static function addTextureAtlasAnimation(target:Dynamic, anim:Dynamic):Void
	{
		if(target == null || anim == null || anim.prefix == null) return;

		var player:Dynamic = Std.isOfType(target, funkin.graphics.FunkinSprite) ? cast(target, funkin.graphics.FunkinSprite).anim : Reflect.getProperty(target, 'anim');
		if(player == null || player == Reflect.getProperty(target, 'animation')) return; //(not a texture atlas)

		var frameRate:Int = (anim.frameRate != null) ? anim.frameRate : 24;
		var looped:Bool = anim.looped == true;
		var flipX:Bool = anim.flipX == true;
		var flipY:Bool = anim.flipY == true;
		var indices:Array<Int> = anim.frameIndices;
		var bySymbol:Bool = (anim.animType == 'symbol');

		if(indices != null && indices.length > 0)
		{
			if(bySymbol) player.addBySymbolIndices(anim.name, anim.prefix, indices, frameRate, looped, flipX, flipY);
			else player.addByFrameLabelIndices(anim.name, anim.prefix, indices, frameRate, looped, flipX, flipY);
		}
		else
		{
			if(bySymbol) player.addBySymbol(anim.name, anim.prefix, frameRate, looped, flipX, flipY);
			else player.addByFrameLabel(anim.name, anim.prefix, frameRate, looped, flipX, flipY);
		}
	}

	public static function addAtlasAnimations(target:FlxSprite, animations:Array<Dynamic>):Void
	{
		if(animations == null) return;
		for (anim in animations)
			addAtlasAnimation(target, anim);
	}

	public static function addTextureAtlasAnimations(target:Dynamic, animations:Array<Dynamic>):Void
	{
		if(animations == null) return;
		for (anim in animations)
			addTextureAtlasAnimation(target, anim);
	}

	public static function combineFramesCollections(a:FlxFramesCollection, b:FlxFramesCollection):FlxFramesCollection
	{
		var result:FlxFramesCollection = new FlxFramesCollection(null, ATLAS, null);
		for (frame in a.frames)
			result.pushFrame(frame);
		for (frame in b.frames)
			result.pushFrame(frame);
		return result;
	}
}
