package funkin.ui.credits;

/**
 * The list V-Slice's credits are made out of. Mods add their own to it: `CreditsDataHandler.CREDITS_DATA.entries.unshift({header: '...', body: [{line: '...'}]})`.
 * It starts empty here, what the scripts of a mod put on it is shown on the engine's credits menu under that mod's name.
 */
class CreditsDataHandler
{
	public static var BACKER_PUBLIC_URL:String = 'https://funkin.me/backers';

	public static var CREDITS_DATA:Dynamic = {entries: []};

	/**
	 * What each mod added, by the name of its folder. Scripts only add theirs once (they keep track of it with `ModStore`), so it's kept from then on.
	 */
	public static var modEntries:Map<String, Array<Dynamic>> = [];

	public static function getFallback():Dynamic
	{
		return {entries: []};
	}

	public static function fetchBackerEntries():Array<String>
	{
		return [];
	}

	static function listEntries():Array<Dynamic>
	{
		return (CREDITS_DATA != null && Std.isOfType(CREDITS_DATA.entries, Array)) ? CREDITS_DATA.entries : [];
	}

	/**
	 * To be called before the scripts of a mod are made, `collect()` then tells what they added.
	 */
	public static function snapshot():Array<Dynamic>
	{
		return listEntries().copy();
	}

	public static function collect(mod:String, before:Array<Dynamic>):Void
	{
		var added:Array<Dynamic> = [for (entry in listEntries()) if(entry != null && !before.contains(entry)) entry];
		if(added.length > 0) modEntries.set(mod, added);
	}
}
