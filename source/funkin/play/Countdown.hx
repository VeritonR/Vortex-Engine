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

	public static function pauseCountdown():Void {}
	public static function resumeCountdown():Void {}
	public static function stopCountdown():Void {}
	public static function skipCountdown():Void {}
	public static function resetCountdown():Void {}
}
