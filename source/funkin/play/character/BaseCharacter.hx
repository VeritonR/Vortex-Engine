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

	public function getDeathCameraOffsets():Array<Float> return [0, 0];
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
