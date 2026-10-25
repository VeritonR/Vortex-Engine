package funkin.effects;

import flixel.FlxObject;
import flixel.util.FlxTimer;

/**
 * What V-Slice scripts get as `flixel.effects.FlxFlicker`: something blinking for a while.
 *
 * The base game's scripts start a second flicker of the same object from inside of the first one's ending
 * (the tankmen that get shot on Stress, Pico's game over), and pause and resume them along with the game.
 * The version of flixel this engine is built with crashes on the first (it gives back to its pool a flicker that's already
 * being used again) and has no way to do the second, so scripts are given this one, which works the same way without a pool.
 */
class ScriptFlicker
{
	static var bound:Map<FlxObject, ScriptFlicker> = new Map<FlxObject, ScriptFlicker>();

	/**
	 * @param Object 				What blinks.
	 * @param Duration 				For how long, in seconds: 0 is until something stops it.
	 * @param Interval 				Seconds between each time it shows up or goes away.
	 * @param EndVisibility 		If it's visible once it's over.
	 * @param ForceRestart 			If one that's already blinking starts over, instead of being left as it is.
	 * @param CompletionCallback 	Called when it's over, with the flicker.
	 * @param ProgressCallback 		Called each time it shows up or goes away.
	 */
	public static function flicker(Object:FlxObject, Duration:Float = 1, Interval:Float = 0.04, EndVisibility:Bool = true, ForceRestart:Bool = true,
		?CompletionCallback:Dynamic, ?ProgressCallback:Dynamic):ScriptFlicker
	{
		if(Object == null) return null;

		var current:ScriptFlicker = bound.get(Object);
		if(current != null)
		{
			if(!ForceRestart) return current;
			current.stop();
		}

		if(Interval <= 0) Interval = FlxG.elapsed;

		var made:ScriptFlicker = new ScriptFlicker();
		made.object = Object;
		made.duration = Duration;
		made.interval = Interval;
		made.endVisibility = EndVisibility;
		made.completionCallback = CompletionCallback;
		made.progressCallback = ProgressCallback;
		made.timer = new FlxTimer().start(Interval, made.progress, Std.int(Duration / Interval));
		bound.set(Object, made);
		return made;
	}

	public static function isFlickering(Object:FlxObject):Bool
	{
		return Object != null && bound.exists(Object);
	}

	public static function stopFlickering(Object:FlxObject):Void
	{
		var current:ScriptFlicker = (Object != null) ? bound.get(Object) : null;
		if(current != null) current.stop();
	}

	public var object(default, null):FlxObject;
	public var endVisibility(default, null):Bool = true;
	public var timer(default, null):FlxTimer;
	public var completionCallback(default, null):Dynamic;
	public var progressCallback(default, null):Dynamic;
	public var duration(default, null):Float = 0;
	public var interval(default, null):Float = 0;

	function new() {}

	/**
	 * Ends it right away, leaving the object visible.
	 */
	public function stop():Void
	{
		if(timer != null) timer.cancel();
		if(object != null)
		{
			object.visible = true;
			release();
		}
	}

	public function pause():Void
	{
		if(timer != null) timer.active = false;
	}

	public function resume():Void
	{
		if(timer != null) timer.active = true;
	}

	public function destroy():Void
	{
		if(timer != null) timer.cancel();
		release();
		timer = null;
		completionCallback = null;
		progressCallback = null;
	}

	function release():Void
	{
		if(object != null && bound.get(object) == this) bound.remove(object);
		object = null;
	}

	function progress(Timer:FlxTimer):Void
	{
		if(object == null) return;

		object.visible = !object.visible;
		if(progressCallback != null) progressCallback(this);

		if(object != null && Timer.loops > 0 && Timer.loopsLeft == 0)
		{
			object.visible = endVisibility;

			// (let go of the object first: what's called next can start another one for it)
			var done:Dynamic = completionCallback;
			release();
			if(done != null) done(this);
		}
	}
}
