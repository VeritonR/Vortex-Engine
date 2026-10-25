package funkin;

/**
 * The player's options with the names V-Slice gives them.
 */
class Preferences
{
	public static var downscroll(get, never):Bool;
	static function get_downscroll():Bool return ClientPrefs.data.downScroll;

	public static var middlescroll(get, never):Bool;
	static function get_middlescroll():Bool return ClientPrefs.data.middleScroll;

	public static var flashingLights(get, never):Bool;
	static function get_flashingLights():Bool return ClientPrefs.data.flashing;

	public static var zoomCamera(get, never):Bool;
	static function get_zoomCamera():Bool return ClientPrefs.data.camZooms;

	public static var naughtyness(get, never):Bool;
	static function get_naughtyness():Bool return ClientPrefs.data.naughtyness;

	// The engine has no subtitles: scripts that ask before setting theirs up are told so
	public static var subtitles(get, never):Bool;
	static function get_subtitles():Bool return false;

	// How the arrows are laid out on a phone's screen
	public static var controlsScheme(get, never):String;
	static function get_controlsScheme():String return 'Arrows';

	public static var autoPause(get, never):Bool;
	static function get_autoPause():Bool return ClientPrefs.data.autoPause;

	public static var framerate(get, never):Int;
	static function get_framerate():Int return ClientPrefs.data.framerate;

	public static var globalOffset(get, never):Int;
	static function get_globalOffset():Int return ClientPrefs.data.noteOffset;

	public static var ghostTapping(get, never):Bool;
	static function get_ghostTapping():Bool return ClientPrefs.data.ghostTapping;

	public static var antialiasing(get, never):Bool;
	static function get_antialiasing():Bool return ClientPrefs.data.antialiasing;

	public static var shaders(get, never):Bool;
	static function get_shaders():Bool return ClientPrefs.data.shaders;

	public static var debugDisplay(get, never):Bool;
	static function get_debugDisplay():Bool return ClientPrefs.data.showFPS;

	public static var unlockedFramerate(get, never):Bool;
	static function get_unlockedFramerate():Bool return false;
}
