package funkin.play.stage;

import funkin.graphics.FunkinSprite;
import funkin.modding.events.ScriptEvent;

/**
 * A sprite of a stage as V-Slice scripts know them: a sprite with a name.
 * The ones of the stage's file are regular sprites here, this is for the ones scripts make themselves.
 */
class StageProp extends FunkinSprite
{
	/**
	 * If it dances with "danceLeft" and "danceRight" by turns (null: if it has those), like V-Slice's Bopper.
	 */
	public var shouldAlternate:Null<Bool> = null;

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
		applyAnimationOffsets(name);
	}

	// ------------------------------------------------------------------------------------------
	// Offsets of each animation, like V-Slice's `Bopper` has (scripts set them when they make one)
	// ------------------------------------------------------------------------------------------

	public var animationOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

	/**
	 * What every animation is moved by, taken out of each animation's own offsets.
	 */
	public var globalOffsets(default, set):Array<Float> = [0, 0];
	function set_globalOffsets(value:Array<Float>):Array<Float>
		return globalOffsets = (value != null && value.length > 1) ? value : [0, 0];

	// The offsets of the animation being played
	public var animOffsets(default, set):Array<Float> = [0, 0];
	function set_animOffsets(value:Array<Float>):Array<Float>
		return animOffsets = (value != null && value.length > 1) ? value : [0, 0];

	public function setAnimationOffsets(name:String, xOffset:Float, yOffset:Float):Void
	{
		animationOffsets.set(name, [xOffset, yOffset]);
		if(name == getCurrentAnimation()) applyAnimationOffsets(name);
	}

	function applyAnimationOffsets(name:String):Void
	{
		animOffsets = (name != null) ? animationOffsets.get(name) : null;
	}

	// (drawn moved by them: "(animOffsets - globalOffsets) * scale")
	override function getScreenPosition(?result:FlxPoint, ?camera:FlxCamera):FlxPoint
	{
		var output:FlxPoint = super.getScreenPosition(result, camera);
		output.x -= (animOffsets[0] - globalOffsets[0]) * scale.x;
		output.y -= (animOffsets[1] - globalOffsets[1]) * scale.y;
		return output;
	}

	override function drawAtlas():Void
	{
		var moveX:Float = (animOffsets[0] - globalOffsets[0]) * scale.x;
		var moveY:Float = (animOffsets[1] - globalOffsets[1]) * scale.y;
		x -= moveX;
		y -= moveY;
		super.drawAtlas();
		x += moveX;
		y += moveY;
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
