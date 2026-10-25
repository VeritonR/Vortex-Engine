package funkin.play.stage;

import funkin.graphics.FunkinSprite;
import funkin.modding.events.ScriptEvent;

/**
 * A sprite of a stage as V-Slice scripts know them: a sprite with a name.
 * The ones of the stage's file are regular sprites here, this is for the ones scripts make themselves.
 */
class StageProp extends FunkinSprite
{
	public var name:String = '';

	/**
	 * Beats between each time the prop dances by itself, 0 for never.
	 */
	public var danceEvery:Float = 0;
	public var shouldBop:Bool = true;

	/**
	 * Added to the name of the animations it dances with: "idle-alt" with "-alt".
	 */
	public var idleSuffix:String = '';

	/**
	 * False while an animation that asked not to be interrupted is playing.
	 */
	public var canPlayOtherAnims:Bool = true;

	var hasDanced:Bool = false;

	public function new()
	{
		super();
	}

	override public function playAnimation(name:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false):Void
	{
		// (an animation the prop doesn't have is looked for without its suffixes, like V-Slice's `Bopper` does)
		while(name != null && !hasAnimation(name))
		{
			var dash:Int = name.lastIndexOf('-');
			name = (dash < 0) ? null : name.substring(0, dash);
		}
		if(name == null) return;
		if(!canPlayOtherAnims && !(restart && getCurrentAnimation() == name)) return;

		super.playAnimation(name, restart, ignoreOther, reversed);
		if(ignoreOther) canPlayOtherAnims = false;
	}

	/**
	 * Plays the animation the prop dances with: "idle", or "danceLeft" and "danceRight" by turns if it has those.
	 */
	public function dance(forceRestart:Bool = false):Void
	{
		if(!canPlayOtherAnims) return;

		if(hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix))
		{
			playAnimation((hasDanced ? 'danceRight' : 'danceLeft') + idleSuffix, forceRestart);
			hasDanced = !hasDanced;
		}
		else playAnimation('idle' + idleSuffix, forceRestart);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(!canPlayOtherAnims && isAnimationFinished()) canPlayOtherAnims = true;
	}

	public function onAdd(event:ScriptEvent):Void {}
	public function onScriptEvent(event:ScriptEvent):Void {}
	public function onCreate(event:ScriptEvent):Void {}
	public function onDestroy(event:ScriptEvent):Void {}
	public function onUpdate(event:UpdateScriptEvent):Void {}
}
