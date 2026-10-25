package funkin.play.character;

import objects.Character;

/**
 * What V-Slice scripts get as the `animation` of a character that's a texture atlas.
 *
 * On V-Slice a texture atlas character's animations are in its `animation` like anyone else's, and scripts check them there
 * (`gf.animation.getNameList().contains('singLEFT')`, the MCM mod's "both-sing" notes). Here they're the atlas', and the character's
 * own `animation` is empty: this answers for them.
 */
@:keep
class AtlasCharacterAnimation
{
	var character:Character;

	public function new(character:Character)
	{
		this.character = character;
	}

	public function getNameList():Array<String>
		return character.listAnimations();

	public function exists(name:String):Bool
		return character.hasAnimation(name);

	public function getByName(name:String):Dynamic
		return exists(name) ? new AtlasCharacterAnimationState(character, name) : null;

	public function play(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		if(exists(name)) character.playAnim(name, force, reversed, frame);
	}

	public function pause():Void
	{
		if(character.atlas != null) character.atlas.anim.pause();
	}

	public function resume():Void
	{
		if(character.atlas != null) character.atlas.anim.resume();
	}

	public function stop():Void
	{
		pause();
	}

	public function finish():Void
	{
		character.finishAnimation();
	}

	public var name(get, never):String;
	function get_name():String
		return character.getAnimationName();

	public var finished(get, never):Bool;
	function get_finished():Bool
		return character.isAnimationFinished();

	public var paused(get, set):Bool;
	function get_paused():Bool
		return character.animPaused;
	function set_paused(value:Bool):Bool
		return character.animPaused = value;

	public var frameIndex(get, set):Int;
	function get_frameIndex():Int
		return (character.atlas != null) ? character.atlas.anim.curFrame : 0;
	function set_frameIndex(value:Int):Int
	{
		if(character.atlas != null) character.atlas.anim.curFrame = value;
		return value;
	}

	public var curAnim(get, never):Dynamic;
	function get_curAnim():Dynamic
	{
		var current:String = character.getAnimationName();
		return (current != null && current.length > 0) ? new AtlasCharacterAnimationState(character, current) : null;
	}
}

/**
 * One animation of a texture atlas character, as `animation.curAnim` / `animation.getByName()` give it to scripts.
 */
@:keep
class AtlasCharacterAnimationState
{
	var character:Character;

	public var name(default, null):String;

	public function new(character:Character, name:String)
	{
		this.character = character;
		this.name = name;
	}

	inline function isCurrent():Bool
		return character.getAnimationName() == name;

	public var finished(get, never):Bool;
	function get_finished():Bool
		return !isCurrent() || character.isAnimationFinished();

	public var paused(get, set):Bool;
	function get_paused():Bool
		return isCurrent() && character.animPaused;
	function set_paused(value:Bool):Bool
	{
		if(isCurrent()) character.animPaused = value;
		return value;
	}

	public var curFrame(get, set):Int;
	function get_curFrame():Int
		return (isCurrent() && character.atlas != null) ? character.atlas.anim.curFrame : 0;
	function set_curFrame(value:Int):Int
	{
		if(isCurrent() && character.atlas != null) character.atlas.anim.curFrame = value;
		return value;
	}

	public var numFrames(get, never):Int;
	function get_numFrames():Int
		return (isCurrent() && character.atlas != null) ? character.atlas.anim.length : 0;

	public function restart():Void
		character.playAnim(name, true);

	public function finish():Void
	{
		if(isCurrent()) character.finishAnimation();
	}
}
