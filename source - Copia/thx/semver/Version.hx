package thx.semver;

/**
 * The library V-Slice keeps the versions of mods with. Here a version is just its text ("1.2.0"),
 * this has the functions scripts use to turn one into the other.
 */
class Version
{
	public static function toString(version:Dynamic):String
	{
		return (version != null) ? Std.string(version) : '';
	}

	public static function stringToVersion(text:String):String
	{
		return text;
	}

	public static function arrayToVersion(parts:Array<Int>):String
	{
		return (parts != null) ? parts.join('.') : '';
	}
}
