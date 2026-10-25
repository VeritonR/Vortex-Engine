package funkin.data.freeplay.player;

import backend.PlayableCharacters;
import funkin.ui.freeplay.charselect.PlayableCharacter;

/**
 * Where V-Slice scripts ask about the playable characters: `PlayerRegistry.instance.fetchEntry('pico')`.
 */
class PlayerRegistry
{
	public static var instance:PlayerRegistry = new PlayerRegistry();

	public function new() {}

	public function hasEntry(id:String):Bool
	{
		return PlayableCharacters.get(id) != null;
	}

	/**
	 * The player with that id: the one a script of the mods made for it when there's one. Null if it doesn't exist.
	 */
	public function fetchEntry(id:String, ?params:Dynamic):PlayableCharacter
	{
		if(id == null) return null;

		#if HSCRIPT_ALLOWED
		var scripted:PlayableCharacter = backend.VSliceScripts.getScriptedPlayer(id);
		if(scripted != null) return scripted;
		#end
		return (PlayableCharacters.get(id) != null) ? new PlayableCharacter(id) : null;
	}

	public function listEntryIds():Array<String>
	{
		return [for (player in PlayableCharacters.list()) player.id];
	}

	public function listBaseGameEntryIds():Array<String>
	{
		return [for (player in PlayableCharacters.list()) if(player.mod == null || player.mod.length < 1) player.id];
	}

	public function listModdedEntryIds():Array<String>
	{
		return [for (player in PlayableCharacters.list()) if(player.mod != null && player.mod.length > 0) player.id];
	}

	public function countUnlockedCharacters():Int
	{
		return PlayableCharacters.countUnlocked();
	}

	// The engine doesn't keep track of which characters the player has already seen being unlocked
	public function hasNewCharacter():Bool return false;
	public function listNewCharacters():Array<String> return [];

	/**
	 * The player a character of a chart belongs to ("bf-christmas" -> "bf"), null if it's nobody's.
	 */
	public function getCharacterOwnerId(characterId:String):String
	{
		var owner = PlayableCharacters.getOwner(characterId);
		return (owner != null) ? owner.id : null;
	}

	public function isCharacterOwned(characterId:String):Bool
	{
		return PlayableCharacters.isCharacterOwned(characterId);
	}
}
