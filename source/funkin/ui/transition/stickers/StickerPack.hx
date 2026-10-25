package funkin.ui.transition.stickers;

/**
 * A sticker pack ("data/stickerpacks/(id).json"): the stickers that cover the screen between some states.
 * Scripts can make packs of their own that pick their stickers some other way (see `funkin.data.stickers.StickerRegistry`).
 */
class StickerPack
{
	public var id(default, null):String;

	/**
	 * What the pack's file has, as it's written (`name`, `artist`, `stickers`).
	 */
	public var _data(default, null):Dynamic;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
		_data = funkin.data.stickers.StickerRegistry.instance.parseEntryData(id);
		if(_data == null) _data = {name: id, artist: '', stickers: []};
	}

	public function getStickerPackName():String return (_data.name != null) ? Std.string(_data.name) : id;
	public function getStickerPackArtist():String return (_data.artist != null) ? Std.string(_data.artist) : '';

	/**
	 * The stickers of the pack, as they're written on its file ("library:path" or "path", inside of "images").
	 */
	public function getStickers():Array<String>
	{
		var list:Array<Dynamic> = Std.isOfType(_data.stickers, Array) ? _data.stickers : [];
		return [for (sticker in list) if(sticker != null) Std.string(sticker)];
	}

	/**
	 * One of the stickers at random, `last` for the one that goes in the middle of the screen at the end.
	 */
	public function getRandomStickerPath(last:Bool):String
	{
		var list:Array<String> = getStickers();
		return (list.length > 0) ? FlxG.random.getObject(list) : null;
	}

	public function toString():String return 'StickerPack($id)';
	public function destroy():Void {}
}
