package funkin;

/**
 * V-Slice's cache. Loading something through `funkin.Paths` already keeps it for the song, which is all scripts ask of this.
 */
class FunkinMemory
{
	// (V-Slice's `Paths.image()` and `Paths.sound()` give the path of the file, and that's what these take there. The ones scripts
	// get here give the image or the sound itself, already loaded: there's nothing left to do with one of those)
	public static function cacheTexture(key:Dynamic):Void
	{
		if(Std.isOfType(key, String) && key.length > 0) Paths.image(stripPath(key, 'images/'));
	}

	public static function permanentCacheTexture(key:Dynamic):Void
	{
		cacheTexture(key);
	}

	public static function cacheSound(key:Dynamic):Void
	{
		if(Std.isOfType(key, String) && key.length > 0) Paths.sound(stripPath(key, 'sounds/'));
	}

	public static function permanentCacheSound(key:Dynamic):Void
	{
		cacheSound(key);
	}

	/**
	 * Loads the pictures and the sounds of a note style (`NoteStyleRegistry.instance.fetchEntry(id)`), the way V-Slice's does.
	 */
	public static function cacheNoteStyle(style:funkin.play.notes.notestyle.NoteStyle):Void
	{
		if(style == null) return;

		for (path in [style.getNoteAssetPath(), style.getHoldNoteAssetPath(), style.getStrumlineAssetPath(), style.getSplashAssetPath()])
			if(path != null) cacheTexture(path);
		for (direction in 0...4)
			cacheTexture(style.getHoldCoverDirectionAssetPath(direction));

		for (step in ['TWO', 'ONE', 'GO'])
			cacheTexture(style.buildCountdownSpritePath(step));
		for (step in ['THREE', 'TWO', 'ONE', 'GO'])
			cacheSound(style.getCountdownSoundPath(step, true));

		for (rating in ['sick', 'good', 'bad', 'shit'])
			cacheTexture(style.buildJudgementSpritePath(rating));
		for (digit in 0...10)
			cacheTexture(style.buildComboNumSpritePath(digit));
	}

	public static function isTextureCached(key:String):Bool return true;
	public static function purgeCache(?callGarbageCollector:Bool):Void {}
	public static function clearFreeplay():Void {}
	public static function clearStickers():Void {}

	// These are given whole paths on V-Slice ("shared:assets/shared/images/thing.png")
	static function stripPath(key:String, folder:String):String
	{
		if(key == null) return '';

		var colon:Int = key.indexOf(':');
		if(colon > -1) key = key.substr(colon + 1);

		var position:Int = key.indexOf(folder);
		if(position > -1) key = key.substr(position + folder.length);

		var dot:Int = key.lastIndexOf('.');
		return (dot > key.lastIndexOf('/')) ? key.substr(0, dot) : key;
	}
}
