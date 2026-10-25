package funkin.util;

/**
 * The values of V-Slice's `Constants` that scripts read. They're regular variables instead of constants so scripts can reach them.
 */
class Constants
{
	public static var TITLE:String = "Friday Night Funkin'";
	public static var VERSION:String = '0.8.0';
	public static var GENERATED_BY:String = 'Vortex Engine';

	// Colors
	public static var COLOR_HEALTH_BAR_RED:FlxColor = 0xFFFF0000;
	public static var COLOR_HEALTH_BAR_GREEN:FlxColor = 0xFF66FF33;

	// Defaults
	public static var DEFAULT_DIFFICULTY:String = 'normal';
	public static var DEFAULT_DIFFICULTY_LIST:Array<String> = ['easy', 'normal', 'hard'];
	public static var DEFAULT_DIFFICULTY_LIST_ERECT:Array<String> = ['erect', 'nightmare'];
	public static var DEFAULT_DIFFICULTY_LIST_FULL:Array<String> = ['easy', 'normal', 'hard', 'erect', 'nightmare'];
	public static var DEFAULT_CHARACTER:String = 'bf';
	public static var DEFAULT_HEALTH_ICON:String = 'face';
	public static var DEFAULT_STAGE:String = 'mainStage';
	public static var DEFAULT_SONG:String = 'tutorial';
	public static var DEFAULT_VARIATION:String = 'default';
	public static var DEFAULT_VARIATION_LIST:Array<String> = ['default', 'erect', 'pico', 'bf'];
	public static var DEFAULT_BOP_INTENSITY:Float = 1.015;
	public static var DEFAULT_ZOOM_RATE:Int = 4;
	public static var DEFAULT_ZOOM_OFFSET:Int = 0;
	public static var DEFAULT_PROP_RATE:Int = 1;
	public static var DEFAULT_BPM:Float = 100.0;
	public static var DEFAULT_SONGNAME:String = 'Unknown';
	public static var DEFAULT_ARTIST:String = 'Unknown';
	public static var DEFAULT_CHARTER:String = 'Unknown';
	public static var DEFAULT_NOTE_STYLE:String = 'funkin';
	public static var DEFAULT_FREEPLAY_STYLE:String = 'bf';
	public static var DEFAULT_PIXEL_NOTE_STYLE:String = 'pixel';
	public static var DEFAULT_ALBUM_ID:String = 'volume1';
	public static var DEFAULT_SCROLLSPEED:Float = 1.0;
	public static var DEFAULT_TIME_SIGNATURE_NUM:Int = 4;
	public static var DEFAULT_TIME_SIGNATURE_DEN:Int = 4;

	public static var ANIMATION_HOLD_SUFFIX:String = '-hold';
	public static var ANIMATION_END_SUFFIX:String = '-end';

	// Timing
	public static var PIXELS_PER_MS:Float = 0.45;
	public static var HIT_WINDOW_MS:Float = 160.0;
	public static var SECS_PER_MIN:Int = 60;
	public static var MS_PER_SEC:Int = 1000;
	public static var STEPS_PER_BEAT:Int = 4;

	// Health, V-Slice's goes from 0 to 2 like Psych's
	public static var HEALTH_MAX:Float = 2.0;
	public static var HEALTH_STARTING:Float = 1.0;
	public static var HEALTH_MIN:Float = 0.0;
	public static var HEALTH_KILLER_BONUS:Float = 0.04;
	public static var HEALTH_SICK_BONUS:Float = 0.03;
	public static var HEALTH_GOOD_BONUS:Float = 0.015;
	public static var HEALTH_BAD_BONUS:Float = 0.0;
	public static var HEALTH_SHIT_BONUS:Float = -0.02;
	public static var HEALTH_HOLD_BONUS_PER_SECOND:Float = 0.12;
	public static var HEALTH_MISS_PENALTY:Float = -0.08;
	public static var HEALTH_GHOST_MISS_PENALTY:Float = -0.08;
	public static var HEALTH_MINE_PENALTY:Float = -0.3;

	// Score
	public static var SCORE_GHOST_MISS_PENALTY:Float = -10.0;
	public static var SCORE_HOLD_BONUS_PER_SECOND:Float = 250.0;
	public static var SCORE_HOLD_DROP_PENALTY_PER_SECOND:Float = -125.0;

	public static var RANK_PERFECT_THRESHOLD:Float = 1.00;
	public static var RANK_EXCELLENT_THRESHOLD:Float = 0.90;
	public static var RANK_GREAT_THRESHOLD:Float = 0.80;
	public static var RANK_GOOD_THRESHOLD:Float = 0.60;

	// If the game is told to keep its swearing down
	public static var CENSOR_EXPLETIVES(get, never):Bool;
	static function get_CENSOR_EXPLETIVES():Bool return !ClientPrefs.data.naughtyness;

	// Vibration, which the engine doesn't do
	public static var DEFAULT_VIBRATION_PERIOD:Float = 0.1;
	public static var DEFAULT_VIBRATION_DURATION:Float = 0.1;
	public static var MIN_VIBRATION_AMPLITUDE:Float = 0.25;
	public static var DEFAULT_VIBRATION_AMPLITUDE:Float = 0.5;
	public static var MAX_VIBRATION_AMPLITUDE:Float = 1;
	public static var DEFAULT_VIBRATION_SHARPNESS:Float = 1;

	// Others
	public static var PIXEL_ART_SCALE:Float = 6;
	public static var EXT_CHART:String = 'fnfc';
	public static var EXT_SOUND:String = 'ogg';
	public static var EXT_VIDEO:String = 'mp4';
	public static var EXT_IMAGE:String = 'png';
	public static var EXT_DATA:String = 'json';

	// The rest of V-Slice's, with its values (the ones about its own build are empty here)
	public static var VERSION_SUFFIX:String = '';
	public static var DEBUG_BUILD:Bool = false;
	public static var URL_MERCH_FALLBACK:String = 'https://needlejuicerecords.com/en-ca/pages/friday-night-funkin';
	public static var URL_ITCH:String = 'https://ninja-muffin24.itch.io/funkin';
	public static var URL_NEWGROUNDS:String = 'https://www.newgrounds.com/portal/view/770371';
	public static var URL_KICKSTARTER:String = 'https://www.kickstarter.com/projects/funkin/friday-night-funkin-the-full-ass-game/';
	public static var GIT_BRANCH:String = '';
	public static var GIT_HASH:String = '';
	public static var GIT_HAS_LOCAL_CHANGES:Bool = false;
	public static var LIBRARY_VERSIONS:Array<String> = [];
	public static var COLOR_NOTES:Array<FlxColor> = [0xFFFF22AA, 0xFF00EEFF, 0xFF00CC00, 0xFFCC1111];
	public static var COLOR_PRELOADER_BG:FlxColor = 0xFF000000;
	public static var COLOR_PRELOADER_BAR:FlxColor = 0xFFA4FF11;
	public static var COLOR_PRELOADER_LOCK_BG:FlxColor = 0xFF1B1717;
	public static var COLOR_PRELOADER_LOCK_FG:FlxColor = 0xB96F10;
	public static var COLOR_PRELOADER_LOCK_FONT:FlxColor = 0xCCCCCC;
	public static var COLOR_PRELOADER_LOCK_LINK:FlxColor = 0xEEB211;
	public static var DEFAULT_STICKER_PACK:String = 'default';
	public static var DEFAULT_OST_NAME:String = 'OFFICIAL OST';
	public static var DEFAULT_PREVIEW_START_TIME:Float = 0;
	public static var DEFAULT_PREVIEW_END_TIME:Float = 0.2;
	public static var DEFAULT_TIMEFORMAT:String = 'ms';
	public static var US_PER_MS:Int = 1000;
	public static var US_PER_SEC:Int = 1000 * 1000;
	public static var NS_PER_US:Int = 1000;
	public static var NS_PER_MS:Int = 1000 * 1000;
	public static var NS_PER_SEC:Int = 1000 * 1000 * 1000;
	public static var MIN_PER_HOUR:Int = 60;
	public static var SECS_PER_HOUR:Int = 60 * 60;
	public static var NOTIFICATION_DISMISS_TIME:Int = 5 * 1000;
	public static var AUTOSAVE_TIMER_DELAY_SEC:Float = 5.0 * 60;
	public static var MP3_DELAY_MS:Float = 528 / 44100 * 1000;
	public static var PRELOADER_MIN_STAGE_TIME:Float = 0.1;
	public static var TITLE_ATTRACT_DELAY:Float = 37.5;
	public static var HEALTH_HOLD_DROP_PENALTY_PER_SECOND:Float = 0;
	public static var HEALTH_HOLD_DROP_PENALTY_MAX:Float = 0;
	public static var HOLD_DROP_PENALTY_THRESHOLD_MS:Float = 160.0;
	public static var JUDGEMENT_KILLER_COMBO_BREAK:Bool = false;
	public static var JUDGEMENT_SICK_COMBO_BREAK:Bool = false;
	public static var JUDGEMENT_GOOD_COMBO_BREAK:Bool = false;
	public static var JUDGEMENT_BAD_COMBO_BREAK:Bool = true;
	public static var JUDGEMENT_SHIT_COMBO_BREAK:Bool = true;
	public static var EXT_STAGE:String = 'fnfs';
	public static var GHOST_TAP_DELAY:Float = 3 / 8;
	public static var LOST_FOCUS_VOLUME_MULTIPLIER:Float = 0.25;
	public static var MAX_PREVIOUS_WORKING_FILES:Int = 10;
	public static var LIBRARY_SEPARATOR:String = ':';
	public static var COUNTDOWN_VOLUME:Float = 0.6;
	/**
	 * Where V-Slice puts the strumlines: this far from the left of the screen (the opponent's) or from its middle (the player's),
	 * and this far from the top (or the bottom on downscroll).
	 */
	public static var STRUMLINE_X_OFFSET:Float = 48;
	public static var STRUMLINE_Y_OFFSET:Float = 24;
	public static var DEFAULT_CAMERA_FOLLOW_RATE:Float = 0.04;
	public static var HEALTH_ICON_ANGLE_HALF_LIFE:Float = 0.512;
	public static var SAVE_PATH:String = 'FunkinCrew';
	public static var SAVE_NAME:String = 'Funkin';
	public static var SAVE_PATH_LEGACY:String = 'ninjamuffin99';
	public static var SAVE_NAME_LEGACY:String = 'funkin';
	public static var BASE_SAVE_SLOT:Int = 1;
}
