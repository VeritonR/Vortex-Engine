package funkin.ui.story;

/**
 * A week ("level") as V-Slice scripts know it, and what V-Slice's week scripts extend.
 * The weeks of a mod are made out of its level files, the scripts made for them aren't run yet: this is here so they load without complaining.
 */
class Level extends funkin.modding.ScriptedBase
{
	public var id(default, null):String;

	/**
	 * The level's file, for the ones made by `LevelRegistry`.
	 */
	public var _data:Dynamic = null;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
	}

	public function isUnlocked():Bool return true;
	public function isVisible():Bool return (_data == null || _data.visible != false);

	public function getTitle():String
	{
		return (_data != null && _data.name != null) ? _data.name : id;
	}

	public function getSongs():Array<String>
	{
		return (_data != null && Std.isOfType(_data.songs, Array)) ? cast(_data.songs, Array<Dynamic>).map(song -> Std.string(song)) : [];
	}

	public function getSongDisplayNames(?difficultyId:String):Array<String> return getSongs();
	public function getDifficulties():Array<String> return [];

	public function toString():String
	{
		return 'Level($id)';
	}
}

class ScriptedLevel extends Level {}
