package funkin.api.newgrounds;

// (V-Slice's Medals is the engine's, scripts get the same one)
typedef Medals = funkin.api.newgrounds.Medals.MedalsSandboxed;

/**
 * V-Slice's Newgrounds medals as scripts get them. The engine doesn't log in to Newgrounds: there's no medal data to fetch.
 */
class MedalsSandboxed
{
	public static function fetchMedalData(medal:Dynamic):Dynamic return null;
	public static function getMedalByStoryLevel(id:String):Dynamic return null;
	public static function getAllMedals():Array<Dynamic> return [];
}
