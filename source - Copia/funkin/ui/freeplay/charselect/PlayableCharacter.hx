package funkin.ui.freeplay.charselect;

import backend.PlayableCharacters;
import funkin.data.freeplay.player.PlayerData.PlayerFreeplayDJData;

/**
 * A playable character as V-Slice scripts know it, and what V-Slice's player scripts extend:
 * `class MyPlayer extends PlayableCharacter` with `super('id')`, to say things about a player that its file can't (if it's unlocked, mostly).
 *
 * The players themselves are the engine's (`backend.PlayableCharacters`, read from the same "data/players" files),
 * this goes to them by the id. What the scripts say is taken when the menus are opened: see `backend.VSliceScripts`.
 */
class PlayableCharacter extends funkin.modding.ScriptedBase
{
	public var id(default, null):String;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
	}

	/**
	 * The engine's player with this id, null if there's no file for it.
	 */
	public var _data(get, never):backend.PlayableCharacters.PlayableCharacter;
	function get__data():backend.PlayableCharacters.PlayableCharacter return PlayableCharacters.get(id);

	public function getName():String
	{
		var data = _data;
		return (data != null) ? data.name : id;
	}

	public function getOwnedCharacterIds():Array<String>
	{
		var data = _data;
		return (data != null) ? data.ownedChars.copy() : [];
	}

	public function shouldShowUnownedChars():Bool
	{
		var data = _data;
		return data != null && data.showUnownedChars;
	}

	public function shouldShowCharacter(id:String):Bool
	{
		var data = _data;
		return data != null && PlayableCharacters.shouldShowCharacter(data, id);
	}

	public function getStickerPackID():String
	{
		var data = _data;
		return (data != null && data.stickerPack != null) ? data.stickerPack : 'default';
	}

	public function getFreeplayStyleID():String
	{
		var data = _data;
		return (data != null && data.freeplayStyle != null) ? data.freeplayStyle : 'bf';
	}

	public function getFreeplayDJData():PlayerFreeplayDJData
	{
		var data = _data;
		return (data != null && data.freeplayDJ != null) ? new PlayerFreeplayDJData(data.freeplayDJ) : null;
	}

	public function getFreeplayDJText(index:Int):String
	{
		var data = _data;
		return new PlayerFreeplayDJData((data != null) ? data.freeplayDJ : null).getFreeplayDJText(index);
	}

	/**
	 * The "charSelect" of the player's file. The engine only keeps part of it: the place on the grid and who sits with the player.
	 */
	public function getCharSelectData():Dynamic
	{
		var data = _data;
		if(data == null) return null;
		return {position: data.position, gf: (data.gfAsset != null) ? {assetPath: data.gfAsset} : null};
	}

	static var rankFields:Array<String> = ['perfectGold', 'perfect', 'excellent', 'great', 'good', 'loss'];

	static function rankField(rank:Dynamic):String
	{
		if(Std.isOfType(rank, Int)) return rankFields[Std.int(Math.max(0, Math.min(rankFields.length - 1, rank)))];

		// "PERFECT_GOLD" -> "perfectGold"
		var parts:Array<String> = Std.string(rank).toLowerCase().split('_');
		for (index in 1...parts.length)
			parts[index] = parts[index].charAt(0).toUpperCase() + parts[index].substr(1);
		return parts.join('');
	}

	/**
	 * What the results screen shows for a rank, as the player's file has it.
	 */
	public function getResultsAnimationDatas(rank:Dynamic):Array<Dynamic>
	{
		var data = _data;
		if(data == null || data.results == null) return [];

		var list:Dynamic = Reflect.field(data.results, rankField(rank));
		return Std.isOfType(list, Array) ? list : [];
	}

	public function getResultsMusicPath(rank:Dynamic):String
	{
		var data = _data;
		var music:Dynamic = (data != null && data.results != null) ? data.results.music : null;
		var name:Dynamic = (music != null) ? Reflect.field(music, rankField(rank)) : null;
		return (name != null) ? Std.string(name) : 'resultsNORMAL';
	}

	/**
	 * If the player can be picked. Scripts override this, without one it's what the player's file says.
	 */
	public function isUnlocked():Bool
	{
		var data = _data;
		return data != null && data.unlocked;
	}

	public function toString():String
	{
		return 'PlayableCharacter($id)';
	}
}

class ScriptedPlayableCharacter extends PlayableCharacter {}
