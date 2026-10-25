package funkin.play;

import flixel.FlxBasic;
import flixel.FlxObject;
import objects.Character;
import substates.GameOverSubstate;

/**
 * The game over as V-Slice scripts know it. The game over itself is the engine's (`substates.GameOverSubstate`),
 * what scripts set here goes to it: the suffixes are how V-Slice picks the sounds of each character ("-pixel", "-pico"...).
 */
@:access(substates.GameOverSubstate)
class GameOverSubState
{
	static var facade:GameOverSubState = null;

	/**
	 * The game over that's on the screen, null when there's none.
	 */
	public static var instance(get, never):GameOverSubState;
	static function get_instance():GameOverSubState
	{
		var real:GameOverSubstate = GameOverSubstate.instance;
		if(real == null || !real.exists)
		{
			facade = null;
			return null;
		}
		if(facade == null || facade.real != real) facade = new GameOverSubState(real);
		return facade;
	}

	/**
	 * Added to the names of the character's death animations on V-Slice, the engine's game over only plays the regular ones.
	 */
	public static var animationSuffix:String = '';

	// What the engine's game over had before a script changed it, to go back to when the script takes its suffix away
	static var defaultLoop:String = null;
	static var defaultEnd:String = null;
	static var defaultDeath:String = null;

	// The first of the names that exists with the suffix, which loses its last part until something is found: "-pixel-pico", "-pixel", ""
	static function find(folder:String, names:Array<String>, suffix:String):String
	{
		while(true)
		{
			for (name in names)
				if(backend.Paths.fileExists('$folder/$name$suffix.${backend.Paths.SOUND_EXT}', folder == 'music' ? MUSIC : SOUND))
					return name + suffix;

			if(suffix.length < 1) return null;

			var parts:Array<String> = suffix.split('-');
			parts.pop();
			suffix = parts.join('-');
		}
	}

	/**
	 * Suffix of the music: "gameOver(suffix)" and "gameOverEnd(suffix)", on V-Slice's folder ("music/gameplay/gameover") or on the music folder itself.
	 */
	public static var musicSuffix(default, set):String = '';
	static function set_musicSuffix(value:String):String
	{
		if(value == null) value = '';
		if(defaultLoop == null)
		{
			defaultLoop = GameOverSubstate.loopSoundName;
			defaultEnd = GameOverSubstate.endSoundName;
		}

		var loop:String = find('music', ['gameplay/gameover/gameOver', 'gameOver'], value);
		var end:String = find('music', ['gameplay/gameover/gameOverEnd', 'gameOverEnd'], value);
		GameOverSubstate.loopSoundName = (loop != null && (value.length > 0 || loop.startsWith('gameplay/'))) ? loop : defaultLoop;
		GameOverSubstate.endSoundName = (end != null && (value.length > 0 || end.startsWith('gameplay/'))) ? end : defaultEnd;
		return musicSuffix = value;
	}

	/**
	 * Suffix of the sound of the character dying: "fnf_loss_sfx(suffix)".
	 */
	public static var blueBallSuffix(default, set):String = '';
	static function set_blueBallSuffix(value:String):String
	{
		if(value == null) value = '';
		if(defaultDeath == null) defaultDeath = GameOverSubstate.deathSoundName;

		var sound:String = find('sounds', ['gameplay/gameover/fnf_loss_sfx', 'fnf_loss_sfx'], value);
		GameOverSubstate.deathSoundName = (sound != null && (value.length > 0 || sound.startsWith('gameplay/'))) ? sound : defaultDeath;
		return blueBallSuffix = value;
	}

	/**
	 * Forgets what the scripts of the last song set.
	 */
	public static function reset():Void
	{
		if(defaultLoop != null)
		{
			GameOverSubstate.loopSoundName = defaultLoop;
			GameOverSubstate.endSoundName = defaultEnd;
		}
		if(defaultDeath != null) GameOverSubstate.deathSoundName = defaultDeath;
		defaultLoop = defaultEnd = defaultDeath = null;

		animationSuffix = '';
		facade = null;

		// (a mod that replaces the base game's own files gets them used from the start, like on V-Slice)
		musicSuffix = '';
		blueBallSuffix = '';
	}

	public static function playBlueBalledSFX():Void
	{
		var sound:openfl.media.Sound = backend.Paths.sound(GameOverSubstate.deathSoundName);
		if(sound != null) FlxG.sound.play(sound);
	}

	// ------------------------------------------------------------------------------------------

	var real:GameOverSubstate;

	/**
	 * On V-Slice it stops the player from leaving or retrying, for the characters that have something to show first.
	 * The engine's game over doesn't wait.
	 */
	public var mustNotExit:Bool = false;

	public var hasPlayedDeathQuote:Bool = false;

	function new(real:GameOverSubstate)
	{
		this.real = real;
	}

	public var boyfriend(get, never):Character;
	function get_boyfriend():Character return real.boyfriend;

	public var cameraFollowPoint(get, never):FlxObject;
	function get_cameraFollowPoint():FlxObject return real.camFollow;

	public var parentPlayState(get, never):PlayState;
	function get_parentPlayState():PlayState return PlayState.instance;

	public function add(object:FlxBasic):FlxBasic return real.add(object);
	public function remove(object:FlxBasic, splice:Bool = false):FlxBasic return real.remove(object, splice);
	public function insert(position:Int, object:FlxBasic):FlxBasic return real.insert(position, object);

	public function startDeathMusic(startingVolume:Float = 1, force:Bool = false):Void
	{
		if(FlxG.sound.music == null || real.isEnding) return;
		if(force || !FlxG.sound.music.playing) real.coolStartDeath(startingVolume);
	}

	// The line the character's script has for whoever died (`getDeathQuote()`), played by the engine's game over
	public function playDeathQuote():Void
	{
		hasPlayedDeathQuote = true;
		real.playDeathQuote();
	}

	public function resetCameraZoom():Void
	{
		var game:states.PlayState = states.PlayState.instance;
		if(game != null) FlxG.camera.zoom = game.defaultCamZoom;
	}

	public function toString():String
	{
		return 'GameOverSubState';
	}
}
