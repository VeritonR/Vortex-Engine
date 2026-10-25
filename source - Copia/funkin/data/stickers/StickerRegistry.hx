package funkin.data.stickers;

import funkin.ui.transition.stickers.StickerPack;

/**
 * Where the sticker packs come from: a script's own pack for an id if one says it's that id, the pack's file if not.
 */
class StickerRegistry
{
	public static var instance(get, never):StickerRegistry;
	static var _instance:StickerRegistry = null;
	static function get_instance():StickerRegistry
	{
		if(_instance == null) _instance = new StickerRegistry();
		return _instance;
	}

	function new() {}

	/**
	 * A sticker pack, null if there's no such pack.
	 */
	public function fetchEntry(id:String, ?params:Dynamic):StickerPack
	{
		if(id == null || id.length < 1) return null;

		#if HSCRIPT_ALLOWED
		var scripted:StickerPack = backend.VSliceScripts.makeStickerPackScript(id);
		if(scripted != null) return scripted;
		#end
		return hasEntry(id) ? new StickerPack(id) : null;
	}

	public function hasEntry(id:String):Bool
	{
		return parseEntryData(id) != null;
	}

	public function parseEntryData(id:String):Dynamic
	{
		if(id == null) return null;
		var raw:String = Paths.getTextFromFile('data/stickerpacks/$id.json');
		if(raw == null) return null;
		if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1);
		try
		{
			return haxe.Json.parse(raw);
		}
		catch(e:Dynamic)
		{
			trace('The sticker pack "$id" could not be read: $e');
			return null;
		}
	}

	public function parseEntryDataWithMigration(id:String, ?version:Dynamic):Dynamic return parseEntryData(id);
}
