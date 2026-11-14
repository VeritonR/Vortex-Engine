package backend;

/**
 * Closes the game.
 *
 * On a phone, closing it from the game's own thread (`Sys.exit()`) runs the program's cleanup while Android's threads (the sound's,
 * the videos') are still using the same memory: it's freed twice, and Android says the game crashed ("app stopped"). There, the
 * process is ended by Android itself instead, once everything that listens to the game's exit (the saves) was told.
 */
class AppExit
{
	/**
	 * @param code     The exit code (0: closed by the player).
	 * @param tellApp  Tell the game's exit to whoever listens to it, the saves (false for the test tool, whose runs aren't saved,
	 *                 and after a crash, when what's in memory can't be trusted).
	 */
	public static function exit(code:Int = 0, tellApp:Bool = true):Void
	{
		#if android
		if(tellApp)
		{
			try
			{
				var app = lime.app.Application.current;
				if(app != null) app.onExit.dispatch(code);
			}
			catch(e:Dynamic) {}
		}
		try
		{
			var myPid:Dynamic = lime.system.JNI.createStaticMethod('android/os/Process', 'myPid', '()I');
			var killProcess:Dynamic = lime.system.JNI.createStaticMethod('android/os/Process', 'killProcess', '(I)V');
			killProcess(myPid());
		}
		catch(e:Dynamic)
		{
			trace('Could not end the process through Android: $e');
		}
		Sys.exit(code); //(only if that didn't work)
		#elseif sys
		if(tellApp) lime.system.System.exit(code); //(tells the game's exit, then closes it)
		else Sys.exit(code);
		#end
	}
}
