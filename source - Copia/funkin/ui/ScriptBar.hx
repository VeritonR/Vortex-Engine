package funkin.ui;

import flixel.ui.FlxBar;

/**
 * flixel's bar, for scripts. A bar can follow a variable of its "parent" by itself, which scripts give as one of their own objects
 * (`new FlxBar(x, y, LEFT_TO_RIGHT, w, h, this, "songPercentage", 0, 1)`). What a script keeps on its objects isn't seen
 * by flixel's way of reading it, and the bar would be empty all the time: here it's read the way scripts do.
 */
class ScriptBar extends FlxBar
{
	override public function update(elapsed:Float):Void
	{
		#if HSCRIPT_ALLOWED
		if(parent != null && hxc.HxcRuntime.getInstance(parent) != null)
		{
			var kept:Dynamic = parent;
			parent = null;
			super.update(elapsed);
			parent = kept;

			updateValueFromParent();
			return;
		}
		#end
		super.update(elapsed);
	}

	override function updateValueFromParent():Void
	{
		#if HSCRIPT_ALLOWED
		var read:Dynamic = hxc.HxcRuntime.getValue(parent, parentVariable);
		if(read != null && Std.isOfType(read, Float) && !Math.isNaN(read)) value = read;
		#else
		super.updateValueFromParent();
		#end
	}
}
