package funkin.util;

/**
 * V-Slice's extra easing functions, for the scripts that use them.
 */
class EaseUtil
{
	/**
	 * An ease that goes in steps instead of smoothly, like the fades of the pixel stages.
	 */
	public static function stepped(steps:Int):Float->Float
	{
		return function(t:Float):Float return Math.floor(t * steps) / steps;
	}
}
