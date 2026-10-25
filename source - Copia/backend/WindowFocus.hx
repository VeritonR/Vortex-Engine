package backend;

import lime.app.Application;

/**
 * Gives the focus back to the game's window when it loses it right after its size changed.
 *
 * Mods' scripts change the window for a song (V-Slice ones take it out of fullscreen and give it another size), and Windows can take
 * the focus away from it while that happens: the game was left without the keys until it was clicked on again.
 */
class WindowFocus
{
	// (how close together the two have to be for one to be what caused the other, in seconds)
	static inline var TIME:Float = 0.5;

	static var installed:Bool = false;
	static var focused:Bool = true;
	static var resizedAt:Float = -1;
	static var lostAt:Float = -1;

	public static function install():Void
	{
		if(installed || Application.current == null || Application.current.window == null) return;
		installed = true;

		var window = Application.current.window;
		window.onFocusIn.add(function() focused = true);
		window.onFocusOut.add(function()
		{
			focused = false;
			lostAt = haxe.Timer.stamp();
			if(lostAt - resizedAt < TIME) giveBack();
		});
		window.onResize.add(function(_, _)
		{
			resizedAt = haxe.Timer.stamp();
			if(!focused && resizedAt - lostAt < TIME) giveBack();
		});
	}

	static function giveBack():Void
	{
		// (not on the game's test runs: their windows are kept out of the way on purpose)
		if(DirectPlay.testRun) return;

		var window = Application.current.window;
		if(window == null || window.minimized) return;
		haxe.Timer.delay(function() if(!focused) window.focus(), 50);
	}
}
