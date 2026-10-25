package hxc;

/**
 * Haxe's `StringTools` as scripts get it (`StringTools.contains(text, "a")`, or `text.contains("a")` with `using StringTools`).
 * Some of Haxe's are inline, which only exist where the game's code uses them: scripts can't call those. Here all of them are real.
 */
class ScriptStringTools
{
	public static function urlEncode(s:String):String return StringTools.urlEncode(s);
	public static function urlDecode(s:String):String return StringTools.urlDecode(s);
	public static function htmlEscape(s:String, ?quotes:Bool):String return StringTools.htmlEscape(s, quotes);
	public static function htmlUnescape(s:String):String return StringTools.htmlUnescape(s);
	public static function contains(s:String, value:String):Bool return s != null && value != null && s.indexOf(value) != -1;
	public static function startsWith(s:String, start:String):Bool return StringTools.startsWith(s, start);
	public static function endsWith(s:String, end:String):Bool return StringTools.endsWith(s, end);
	public static function isSpace(s:String, pos:Int):Bool return StringTools.isSpace(s, pos);
	public static function ltrim(s:String):String return StringTools.ltrim(s);
	public static function rtrim(s:String):String return StringTools.rtrim(s);
	public static function trim(s:String):String return StringTools.trim(s);
	public static function lpad(s:String, c:String, l:Int):String return StringTools.lpad(s, c, l);
	public static function rpad(s:String, c:String, l:Int):String return StringTools.rpad(s, c, l);
	public static function replace(s:String, sub:String, by:String):String return StringTools.replace(s, sub, by);
	public static function hex(n:Int, ?digits:Int):String return StringTools.hex(n, digits);
	public static function fastCodeAt(s:String, index:Int):Int return StringTools.fastCodeAt(s, index);
	public static function unsafeCodeAt(s:String, index:Int):Int return StringTools.unsafeCodeAt(s, index);
	public static function iterator(s:String):Iterator<Int> return new haxe.iterators.StringIterator(s);
	public static function keyValueIterator(s:String):KeyValueIterator<Int, Int> return new haxe.iterators.StringKeyValueIterator(s);
	public static function isEof(c:Int):Bool return StringTools.isEof(c);
	public static function quoteUnixArg(argument:String):String return haxe.SysTools.quoteUnixArg(argument);
	public static function quoteWinArg(argument:String, escapeMetaCharacters:Bool):String return haxe.SysTools.quoteWinArg(argument, escapeMetaCharacters);
}
