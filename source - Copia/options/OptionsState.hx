package options;

/**
 * The options menu as a screen of its own: what a song's pause menu opens (`onPlayState`), and where "Adjust Delay and Combo" comes back
 * to. The menu itself is `OptionsMenu`, which the main menu opens right on top of itself instead.
 */
class OptionsState extends MusicBeatState
{
	public static var onPlayState:Bool = false;

	/**
	 * The option the menu is on, kept from one time it's opened to the next.
	 */
	public static var curSelected:Int = 0;

	override function create()
	{
		persistentUpdate = false;
		persistentDraw = true;
		super.create();

		openSubState(new OptionsMenu(onPlayState, false));
	}
}
