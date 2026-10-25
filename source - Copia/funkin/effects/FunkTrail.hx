package funkin.effects;

import flixel.addons.effects.FlxTrail;
import flixel.system.FlxAssets.FlxGraphicAsset;

/**
 * V-Slice's trail of copies behind a sprite. Its version only exists to deal with the way V-Slice's characters keep their animation offsets,
 * Psych's keep theirs where the library's own trail already looks at.
 */
class FunkTrail extends FlxTrail
{
	public var frameOffset(default, null):FlxPoint = FlxPoint.get();

	public function new(target:FlxSprite, ?graphic:FlxGraphicAsset, length:Int = 10, delay:Float = 0.1, alpha:Float = 0.4, diff:Float = 0.05)
	{
		super(target, graphic, length, Std.int(Math.max(1, Math.round(delay * 60))), alpha, diff);
	}

	override function destroy():Void
	{
		super.destroy();
		if(frameOffset != null) frameOffset.put();
		frameOffset = null;
	}
}
