package funkin.play.character;

import funkin.modding.events.ScriptEvent;
import objects.Character;

#if HSCRIPT_ALLOWED
import hxc.HxcRuntime.IHxcMixin;
#end

/**
 * What V-Slice character scripts extend. Characters here are Psych's own `objects.Character`:
 * a script whose id is the one of a character on the song gets attached to it, so inside of the script `this` is the Psych character
 * (which knows the names V-Slice gives to the most common things, like `playAnimation()`).
 *
 * An object of this class goes along with each of those scripts, with what V-Slice's characters have and Psych's don't:
 * it's where `super.onNoteHit(event)` and the like end up at.
 */
class BaseCharacter extends funkin.modding.ScriptedBase #if HSCRIPT_ALLOWED implements IHxcMixin #end
{
	public var characterId(default, null):String;

	/**
	 * The Psych character the script is attached to, null on the objects that are only made to read the script's id.
	 */
	public var character(default, null):Character = null;

	/**
	 * If the character was told to sing the note that's being hit.
	 * V-Slice's characters do it on their `onNoteHit()`, which scripts skip (by not calling `super.onNoteHit(event)`) when they want something else.
	 */
	public var sang:Bool = false;

	// The same for the note that's being missed
	public var missed:Bool = false;

	/**
	 * Animations (by how their names start) that can be played over one that asked not to be interrupted, scripts add theirs when they're made.
	 * The ones of the character the script is attached to are what counts, these are passed on to it.
	 */
	public var ignoreExclusionPref:Array<String> = ['sing'];

	public function new(id:String, ?renderType:Dynamic)
	{
		characterId = id;
	}

	public function attachTo(target:Dynamic):Void
	{
		character = Std.downcast(target, Character);
	}

	/**
	 * Called when the character is put on the stage.
	 */
	public function onAdd(event:ScriptEvent):Void {}

	override public function onNoteHit(event:HitNoteScriptEvent):Void
	{
		sang = true;
	}

	override public function onNoteMiss(event:NoteScriptEvent):Void
	{
		missed = true;
	}

	/**
	 * Called with each frame of the character's animations, for the ones that aren't texture atlases.
	 */
	public function onAnimationFrame(name:String = '', frameNumber:Int = -1, frameIndex:Int = -1):Void {}

	public function onAnimationFinished(name:String = ''):Void {}

	/**
	 * If the player is holding a note's key (V-Slice's): characters keep singing while it's held.
	 */
	@:access(states.PlayState)
	public function isHoldingNote(player:Int = 1):Bool
	{
		var game:states.PlayState = states.PlayState.instance;
		if(game == null || player != 1 || game.keysArray == null) return false;
		for (key in game.keysArray)
			if(game.controls.pressed(key)) return true;
		return false;
	}

	/**
	 * If the player just pressed a note's key (V-Slice's).
	 */
	@:access(states.PlayState)
	public function justPressedNote(player:Int = 1):Bool
	{
		var game:states.PlayState = states.PlayState.instance;
		if(game == null || player != 1 || game.keysArray == null) return false;
		for (key in game.keysArray)
			if(game.controls.justPressed(key)) return true;
		return false;
	}

	// What the character's file says (V-Slice's `_data`), as scripts read it
	function data():Dynamic
	{
		#if HSCRIPT_ALLOWED
		if(character != null) return hxc.HxcRuntime.readMember(character, '_data');
		#end
		return null;
	}

	public function getDeathCameraZoom():Float
	{
		var death:Dynamic = (data() != null) ? data().death : null;
		return (death != null && death.cameraZoom != null) ? death.cameraZoom : 1.0;
	}

	public function getDeathPreTransitionDelay():Float
	{
		var death:Dynamic = (data() != null) ? data().death : null;
		return (death != null && death.preTransitionDelay != null) ? death.preTransitionDelay : 0.0;
	}

	public var characterCameraOffsets(get, never):Array<Float>;
	function get_characterCameraOffsets():Array<Float>
	{
		var offsets:Dynamic = (data() != null) ? data().cameraOffsets : null;
		return (offsets != null) ? offsets : [0.0, 0.0];
	}

	/**
	 * The numbers of the character's animations named that way followed by one ("combo50", "drop10"...), smallest first.
	 */
	public function findCountAnimations(prefix:String):Array<Int>
	{
		var result:Array<Int> = [];
		if(character == null || character.animOffsets == null) return result;
		for (name in character.animOffsets.keys())
		{
			if(!StringTools.startsWith(name, prefix)) continue;
			var count:Null<Int> = Std.parseInt(name.substr(prefix.length));
			if(count != null && !result.contains(count)) result.push(count);
		}
		result.sort((a, b) -> a - b);
		return result;
	}

	public function playComboAnimation(comboCount:Int):Void
	{
		if(character != null && character.hasAnimation('combo$comboCount')) character.playAnim('combo$comboCount', true);
	}

	// (the highest "drop" animation the combo that was lost reaches)
	public function playComboDropAnimation(comboCount:Int):Void
	{
		var drop:String = null;
		for (count in findCountAnimations('drop'))
			if(comboCount >= count) drop = 'drop$count';
		if(drop != null && character != null) character.playAnim(drop, true);
	}

	public function getDeathCameraOffsets():Array<Float>
	{
		var death:Dynamic = (data() != null) ? data().death : null;
		return (death != null && death.cameraOffsets != null) ? death.cameraOffsets : [0.0, 0.0];
	}
	public function getDeathQuote():String return null;
}

class SparrowCharacter extends BaseCharacter {}
class MultiSparrowCharacter extends BaseCharacter {}
class PackerCharacter extends BaseCharacter {}
class AnimateAtlasCharacter extends BaseCharacter {}
class MultiAnimateAtlasCharacter extends BaseCharacter {}

/**
 * On V-Slice this is a script of the base game (Pico as the player, with his own game over) that mods extend for their own Picos.
 * Here it's a regular character, the game over stays being the engine's.
 */
class PicoPlayerBaseCharacter extends MultiAnimateAtlasCharacter {}
