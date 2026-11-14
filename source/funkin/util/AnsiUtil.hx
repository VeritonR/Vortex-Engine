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

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum abstract AnsiCode(String) from String to String
{
	public var RESET = '\x1b[0m';
	public var BOLD = '\x1b[1m';
	public var DIM = '\x1b[2m';
	public var UNDERLINE = '\x1b[4m';
	public var BLINK = '\x1b[5m';
	public var INVERSE = '\x1b[7m';
	public var HIDDEN = '\x1b[8m';
	public var STRIKETHROUGH = '\x1b[9m';
	// 30-37 set foreground to standard colors
	public var BLACK = '\x1b[30m';
	public var RED = '\x1b[31m';
	public var GREEN = '\x1b[32m';
	public var YELLOW = '\x1b[33m';
	public var BLUE = '\x1b[34m';
	public var MAGENTA = '\x1b[35m';
	public var CYAN = '\x1b[36m';
	public var WHITE = '\x1b[37m';
	// 38 has two modes
	// [38;2;#m uses one of 256 colors
	public var ORANGE = '\x1b[38;5;208m';
	// [38;2;RR;GG;BBm uses 24-bit color RGB
	public var NOTE_LEFT = '\x1b[38;2;255;34;170m';
	public var NOTE_DOWN = '\x1b[38;2;0;238;255m';
	public var NOTE_UP = '\x1b[38;2;0;204;0m';
	public var NOTE_RIGHT = '\x1b[38;2;204;17;17m';
	// 40-47 set background to standard colors
	public var BG_BLACK = '\x1b[40m';
	public var BG_RED = '\x1b[41m';
	public var BG_GREEN = '\x1b[42m';
	public var BG_YELLOW = '\x1b[43m';
	public var BG_BLUE = '\x1b[44m';
	public var BG_MAGENTA = '\x1b[45m';
	public var BG_CYAN = '\x1b[46m';
	public var BG_WHITE = '\x1b[47m';
	// 48 has two modes
	// [48;2;#m uses one of 256 colors
	// Color names via https://hexdocs.pm/color_palette/ansi_color_codes.html
	public var BG_SEA_GREEN = '\x1b[48;5;50m';
	public var BG_PIST = '\x1b[48;5;112m';
	public var BG_BRONZE = '\x1b[48;5;137m';
	public var BG_BRIGHT_LAVENDER = '\x1b[48;5;141m';
	public var BG_LIME = '\x1b[48;5;154m';
	public var BG_MINT_GREEN = '\x1b[48;5;156m';
	public var BG_HOPBUSH = '\x1b[48;5;169m';
	public var BG_BRIGHT_LILAC = '\x1b[48;5;177m';
	public var BG_GOLDENROD = '\x1b[48;5;178m';
	public var BG_CORN = '\x1b[48;5;184m';
	public var BG_TEA_GREEN = '\x1b[48;5;193m';
	public var BG_LIGHT_RED = '\x1b[48;5;196m';
	public var BG_STRAWBERRY = '\x1b[48;5;204m';
	public var BG_SHOCKING_PINK = '\x1b[48;5;207m';
	public var BG_ORANGE = '\x1b[48;5;208m';
	public var BG_SALMON = '\x1b[48;5;209m';
	public var BG_LIGHT_PINK = '\x1b[48;5;213m';
	// [48;2;RR;GG;BBm uses 24-bit color RGB
	public var BG_PURPLE = '\x1b[48;2;121;37;199m';
	public var BG_NOTE_LEFT = '\x1b[48;2;255;34;170m';
	public var BG_NOTE_DOWN = '\x1b[48;2;0;238;255m';
	public var BG_NOTE_UP = '\x1b[48;2;0;204;0m';
	public var BG_NOTE_RIGHT = '\x1b[48;2;204;17;17m';
	// 90-97 sets a bright foreground color (non-standard)
	public var BRIGHT_BLACK = '\x1b[90m';
	public var BRIGHT_RED = '\x1b[91m';
	public var BRIGHT_GREEN = '\x1b[92m';
	public var BRIGHT_YELLOW = '\x1b[93m';
	public var BRIGHT_BLUE = '\x1b[94m';
	public var BRIGHT_MAGENTA = '\x1b[95m';
	public var BRIGHT_CYAN = '\x1b[96m';
	public var BRIGHT_WHITE = '\x1b[97m';
	// 100-107 sets a bright background color (non-standard)
	public var BG_BRIGHT_BLACK = '\x1b[100m';
	public var BG_BRIGHT_RED = '\x1b[101m';
	public var BG_BRIGHT_GREEN = '\x1b[102m';
	public var BG_BRIGHT_YELLOW = '\x1b[103m';
	public var BG_BRIGHT_BLUE = '\x1b[104m';
	public var BG_BRIGHT_MAGENTA = '\x1b[105m';
	public var BG_BRIGHT_CYAN = '\x1b[106m';
	public var BG_BRIGHT_WHITE = '\x1b[107m';
}
