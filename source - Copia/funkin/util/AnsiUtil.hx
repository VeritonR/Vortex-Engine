package funkin.util;

/**
 * V-Slice's functions for coloring what's written to the console: `using funkin.util.AnsiUtil;` and then `' TEXT '.bold().bg_red()`.
 * The engine's console doesn't do colors, so every one of them gives the text back as it is.
 */
class AnsiUtil
{
	/**
	 * Names of the functions, for the scripts' `using`.
	 */
	public static var NAMES:Array<String> = [
		'error', 'warning', 'info', 'bold', 'dim', 'underline', 'blink', 'inverse',
		'hidden', 'strikethrough', 'black', 'red', 'green', 'yellow', 'blue', 'magenta',
		'cyan', 'white', 'bg_black', 'bg_red', 'bg_green', 'bg_yellow', 'bg_blue', 'bg_magenta',
		'bg_cyan', 'bg_white', 'bg_orange', 'bg_purple', 'bg_bright_lilac', 'bg_note_left', 'bg_note_down', 'bg_note_up',
		'bg_note_right', 'bright_black', 'bright_red', 'bright_green', 'bright_yellow', 'bright_blue', 'bright_magenta', 'bright_cyan',
		'bright_white', 'bg_bright_black', 'bg_bright_red', 'bg_bright_green', 'bg_bright_yellow', 'bg_bright_blue', 'bg_bright_magenta', 'bg_bright_cyan',
		'bg_bright_white'
	];

	public static function error(str:String):String return str;
	public static function warning(str:String):String return str;
	public static function info(str:String):String return str;
	public static function bold(str:String):String return str;
	public static function dim(str:String):String return str;
	public static function underline(str:String):String return str;
	public static function blink(str:String):String return str;
	public static function inverse(str:String):String return str;
	public static function hidden(str:String):String return str;
	public static function strikethrough(str:String):String return str;
	public static function black(str:String):String return str;
	public static function red(str:String):String return str;
	public static function green(str:String):String return str;
	public static function yellow(str:String):String return str;
	public static function blue(str:String):String return str;
	public static function magenta(str:String):String return str;
	public static function cyan(str:String):String return str;
	public static function white(str:String):String return str;
	public static function bg_black(str:String):String return str;
	public static function bg_red(str:String):String return str;
	public static function bg_green(str:String):String return str;
	public static function bg_yellow(str:String):String return str;
	public static function bg_blue(str:String):String return str;
	public static function bg_magenta(str:String):String return str;
	public static function bg_cyan(str:String):String return str;
	public static function bg_white(str:String):String return str;
	public static function bg_orange(str:String):String return str;
	public static function bg_purple(str:String):String return str;
	public static function bg_bright_lilac(str:String):String return str;
	public static function bg_note_left(str:String):String return str;
	public static function bg_note_down(str:String):String return str;
	public static function bg_note_up(str:String):String return str;
	public static function bg_note_right(str:String):String return str;
	public static function bright_black(str:String):String return str;
	public static function bright_red(str:String):String return str;
	public static function bright_green(str:String):String return str;
	public static function bright_yellow(str:String):String return str;
	public static function bright_blue(str:String):String return str;
	public static function bright_magenta(str:String):String return str;
	public static function bright_cyan(str:String):String return str;
	public static function bright_white(str:String):String return str;
	public static function bg_bright_black(str:String):String return str;
	public static function bg_bright_red(str:String):String return str;
	public static function bg_bright_green(str:String):String return str;
	public static function bg_bright_yellow(str:String):String return str;
	public static function bg_bright_blue(str:String):String return str;
	public static function bg_bright_magenta(str:String):String return str;
	public static function bg_bright_cyan(str:String):String return str;
	public static function bg_bright_white(str:String):String return str;

	public static function apply(str:String, ?code:Dynamic):String return str;
	public static function isColorCodesSupported():Bool return false;
}
