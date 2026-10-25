package funkin.ui.freeplay;

/**
 * The album art of V-Slice's Freeplay menu. The engine's Freeplay shows its own (see `states.FreeplayStateVslice`), this is so
 * the scripts that name it can be loaded.
 */
class AlbumRoll extends FlxSpriteGroup
{
	public var albumId(default, set):String = null;
	function set_albumId(value:String):String return albumId = value;

	public function new()
	{
		super();
	}

	public function playIntro():Void {}
	public function skipIntro():Void {}
	public function showTitle():Void {}
	public function showStars():Void {}
	public function setDifficultyStars(?difficulty:Int):Void {}
}
