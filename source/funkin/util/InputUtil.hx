package funkin.util;

import flixel.input.keyboard.FlxKey;

/**
 * V-Slice's names of the keys, for the scripts that show them.
 */
class InputUtil
{
	public static function getKeyName(key:Int):String
	{
		if(key < 0) return '[?]';
		var name:String = FlxKey.toStringMap.get(key);
		return (name != null) ? name : '[?]';
	}

	public static function format(key:Int):String return getKeyName(key);
}
