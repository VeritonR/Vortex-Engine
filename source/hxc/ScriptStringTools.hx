package hxc;

/**
 * Haxe's `StringTools` as scripts get it (`StringTools.contains(text, "a")`, or `text.contains("a")` with `using StringTools`).
 * Some of Haxe's are inline, which only exist where the game's code uses them: scripts can't call those. Here all of them are real.
 */
class ScriptStringTools
{
	// On V-Slice `Paths.image()` gives the image's path, here the image itself (scripts load it right away): text functions given one
	// work with its path ("images/thing.png"), like a script that looks for the ".json" beside it does (SKYREBORN's gallery).
	// Nothing found is no text at all, where V-Slice would have given a path that isn't there
	static function text(s:Dynamic):String
	{
		if(s == null) return '';
		if(Std.isOfType(s, flixel.graphics.FlxGraphic)) return cast(s, flixel.graphics.FlxGraphic).key;
		return Std.string(s);
	}

	public static function urlEncode(s:Dynamic):String return StringTools.urlEncode(text(s));
	public static function urlDecode(s:Dynamic):String return StringTools.urlDecode(text(s));
	public static function htmlEscape(s:Dynamic, ?quotes:Bool):String return StringTools.htmlEscape(text(s), quotes);
	public static function htmlUnescape(s:Dynamic):String return StringTools.htmlUnescape(text(s));
	public static function contains(s:Dynamic, value:String):Bool return text(s) != null && value != null && text(s).indexOf(value) != -1;
	public static function startsWith(s:Dynamic, start:String):Bool return StringTools.startsWith(text(s), start);
	public static function endsWith(s:Dynamic, end:String):Bool return StringTools.endsWith(text(s), end);
	public static function isSpace(s:Dynamic, pos:Int):Bool return StringTools.isSpace(text(s), pos);
	public static function ltrim(s:Dynamic):String return StringTools.ltrim(text(s));
	public static function rtrim(s:Dynamic):String return StringTools.rtrim(text(s));
	public static function trim(s:Dynamic):String return StringTools.trim(text(s));
	public static function lpad(s:Dynamic, c:String, l:Int):String return StringTools.lpad(text(s), c, l);
	public static function rpad(s:Dynamic, c:String, l:Int):String return StringTools.rpad(text(s), c, l);
	public static function replace(s:Dynamic, sub:String, by:String):String return StringTools.replace(text(s), sub, by);
	public static function hex(n:Int, ?digits:Int):String return StringTools.hex(n, digits);
	public static function fastCodeAt(s:Dynamic, index:Int):Int return StringTools.fastCodeAt(text(s), index);
	public static function unsafeCodeAt(s:Dynamic, index:Int):Int return StringTools.unsafeCodeAt(text(s), index);
	public static function iterator(s:Dynamic):Iterator<Int> return new haxe.iterators.StringIterator(text(s));
	public static function keyValueIterator(s:Dynamic):KeyValueIterator<Int, Int> return new haxe.iterators.StringKeyValueIterator(text(s));
	public static function isEof(c:Int):Bool return StringTools.isEof(c);
	public static function quoteUnixArg(argument:String):String return haxe.SysTools.quoteUnixArg(argument);
	public static function quoteWinArg(argument:String, escapeMetaCharacters:Bool):String return haxe.SysTools.quoteWinArg(argument, escapeMetaCharacters);
}
