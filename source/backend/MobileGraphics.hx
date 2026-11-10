package backend;

/**
 * The "Render Resolution" option (Graphics, phones only): how many lines of pixels the game is drawn at. A phone's screen has
 * many more pixels than the game's 1280x720 (2400x1080 is 2.6 million, drawn again for every layer of a stage), and filling them
 * is what slows its graphics card down; drawn at fewer, the phone's screen stretches it by itself, at no cost.
 * "720p" is as many lines as the game has, which is the default: what's drawn above that is the art made bigger.
 */
class MobileGraphics
{
	public static final RESOLUTIONS:Array<String> = ['Native', '1080p', '900p', '720p', '540p'];

	/**
	 * Draws the game at the option's resolution. Nothing on computers.
	 */
	public static function apply():Void
	{
		#if android
		var lines:Int = switch(ClientPrefs.data.renderResolution)
		{
			case '1080p': 1080;
			case '900p': 900;
			case '720p': 720;
			case '540p': 540;
			default: 0;
		}
		try
		{
			var setLines:Dynamic = lime.system.JNI.createStaticMethod('com/veriton/vortexengine/RenderScale', 'setLines', '(I)V');
			if(setLines != null) setLines(lines);
		}
		catch(e:Dynamic)
		{
			trace('Could not change the resolution: $e');
		}
		#end
	}
}
