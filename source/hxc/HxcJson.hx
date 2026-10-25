package hxc;

#if HSCRIPT_ALLOWED
/**
 * `haxe.Json` for the scripts. The functions of the real one are put right where they're used when the game is built,
 * so there's nothing of them left to be found by name while it runs: `Json.parse()` wouldn't exist for a script.
 */
class HxcJson
{
	public static function parse(text:String):Dynamic
	{
		return haxe.Json.parse(text);
	}

	public static function stringify(value:Dynamic, ?replacer:(key:Dynamic, value:Dynamic) -> Dynamic, ?space:String):String
	{
		return haxe.Json.stringify(value, replacer, space);
	}
}
#end
