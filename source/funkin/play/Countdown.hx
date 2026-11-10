package funkin.play;

/**
 * V-Slice's countdown, which is Psych's own here. Scripts that stopped it to show something use this to start it afterwards.
 */
class Countdown
{
	public static var soundSuffix:String = '';
	public static var graphicSuffix:String = '';

	/**
	 * Starts the countdown of the song, returns false if there's no song to start.
	 */
	public static function performCountdown():Bool
	{
		var game:states.PlayState = states.PlayState.instance;
		if(game == null) return false;

		game.inCutscene = false;
		game.startCountdown();
		return true;
	}

	/**
	 * Stops the countdown on the tick it's at, until `resumeCountdown()`.
	 */
	public static function pauseCountdown():Void
	{
		var timer:flixel.util.FlxTimer = countdownTimer();
		if(timer != null && !timer.finished) timer.active = false;
	}

	public static function resumeCountdown():Void
	{
		var timer:flixel.util.FlxTimer = countdownTimer();
		if(timer != null && !timer.finished) timer.active = true;
	}

	/**
	 * Takes away the rest of the countdown's ticks (like on V-Slice, the song still starts when its time comes).
	 */
	public static function stopCountdown():Void
	{
		var timer:flixel.util.FlxTimer = countdownTimer();
		if(timer != null) timer.cancel();
	}

	/**
	 * Stops the countdown and starts the song right away (Ejected, Soulless, Monster... do it as soon as the countdown starts).
	 */
	public static function skipCountdown():Void
	{
		stopCountdown();

		var game:states.PlayState = states.PlayState.instance;
		if(game != null && game.startingSong && @:privateAccess game.startedCountdown) backend.Conductor.songPosition = backend.Conductor.offset;
	}

	/**
	 * Starts the countdown's ticks over, if it's still going.
	 */
	public static function resetCountdown():Void
	{
		var timer:flixel.util.FlxTimer = countdownTimer();
		if(timer != null && !timer.finished) timer.reset();
	}

	static function countdownTimer():flixel.util.FlxTimer
	{
		var game:states.PlayState = states.PlayState.instance;
		return (game != null) ? @:privateAccess game.startTimer : null;
	}
}
