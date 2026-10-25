package funkin.util;

/**
 * V-Slice's functions to pause the tweens of something, like `FlxTween.cancelTweensOf()` cancels them.
 */
class FlxTweenUtil
{
	public static function pauseTween(tween:FlxTween):Void
	{
		if(tween != null) tween.active = false;
	}

	public static function resumeTween(tween:FlxTween):Void
	{
		if(tween != null) tween.active = true;
	}

	public static function pauseTweensOf(object:Dynamic, ?fieldPaths:Array<String>):Void
	{
		if(object == null) return;

		@:privateAccess
		FlxTween.globalManager.forEachTweensOf(object, fieldPaths, pauseTween);
	}

	public static function resumeTweensOf(object:Dynamic, ?fieldPaths:Array<String>):Void
	{
		if(object == null) return;

		@:privateAccess
		FlxTween.globalManager.forEachTweensOf(object, fieldPaths, resumeTween);
	}
}
