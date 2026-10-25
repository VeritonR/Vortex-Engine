package funkin.modding;

import haxe.ds.StringMap;

/**
 * V-Slice's place for mods to keep things in until the game is closed. Scripts are made again for every song here, this stays.
 */
class ModStore
{
	public static var stores:StringMap<Dynamic> = new StringMap<Dynamic>();

	/**
	 * Makes a store with that name, or gives back the one that already has it.
	 */
	public static function register(id:String, ?data:Dynamic):Dynamic
	{
		if(stores.exists(id)) return stores.get(id);

		if(data == null) data = {};
		stores.set(id, data);
		return data;
	}

	public static function get(id:String):Dynamic
	{
		return stores.get(id);
	}

	public static function remove(id:String):Dynamic
	{
		var data:Dynamic = stores.get(id);
		stores.remove(id);
		return data;
	}
}
