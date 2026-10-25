package funkin.util;

import flixel.util.FlxSignal.FlxTypedSignal;

/**
 * V-Slice's shortcuts for the game's window, for the scripts that use them.
 */
class WindowUtil
{
	/**
	 * Told when the window is about to be closed, with the code the game is ending with.
	 */
	public static var windowExit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	static var watching:Bool = false;

	/**
	 * Makes `windowExit` work. Called once scripts are being used.
	 */
	public static function initWindowEvents():Void
	{
		if(watching) return;
		watching = true;

		lime.app.Application.current.onExit.add(function(code:Int) windowExit.dispatch(code));
	}

	/**
	 * Opens a page on the browser. Only web addresses: anything else is left alone.
	 */
	public static function openURL(targetUrl:String):Void
	{
		if(targetUrl == null) return;

		var url:String = StringTools.trim(targetUrl);
		if(!StringTools.startsWith(url, 'http://') && !StringTools.startsWith(url, 'https://')) return;

		CoolUtil.browserLoad(url);
	}

	public static function setWindowTitle(value:String):Void
	{
		lime.app.Application.current.window.title = value;
	}

	public static function showError(name:String, desc:String):Void
	{
		lime.app.Application.current.window.alert(desc, name);
	}

	public static function showWarning(name:String, desc:String):Void
	{
		lime.app.Application.current.window.alert(desc, name);
	}

	public static function showInformation(name:String, desc:String):Void
	{
		lime.app.Application.current.window.alert(desc, name);
	}
}
