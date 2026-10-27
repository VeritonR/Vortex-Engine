package funkin.audio;

import openfl.media.Sound;

/**
 * V-Slice's sound class: a regular sound, with the shortcuts scripts use to play things.
 * Sounds can be given as what `funkin.Paths` returns or as their path inside the sounds folder.
 */
class FunkinSound extends FlxSound
{
	/**
	 * Sounds made by scripts (`new FunkinSound().loadEmbedded(...)`) go with the others, so they stop when leaving the song.
	 */
	public function new()
	{
		super();
		FlxG.sound.list.add(this);
	}

	public var isPlaying(get, never):Bool;
	function get_isPlaying():Bool return playing;

	public var muted(default, set):Bool = false;
	function set_muted(value:Bool):Bool
	{
		if(value == muted) return value;

		if(value) unmutedVolume = volume;
		muted = value;
		volume = value ? 0 : unmutedVolume;
		return value;
	}
	var unmutedVolume:Float = 1;

	public function togglePlayback():FunkinSound
	{
		if(playing) pause();
		else resume();
		return this;
	}

	// Takes a sound out of everything of the game that keeps track of it
	static function forget(sound:FlxSound):Void
	{
		@:privateAccess
		{
			FlxG.sound.defaultSoundGroup.sounds.remove(sound);
			FlxG.sound.defaultMusicGroup.sounds.remove(sound);
			if(sound.group != null) sound.group.sounds.remove(sound);
		}
		Reflect.setField(sound, 'group', null); //without what the sound does when its group changes, which a destroyed one can't do
		FlxG.sound.list.remove(sound, true);
		if(FlxG.sound.music == sound) FlxG.sound.music = null;
	}

	/**
	 * Gets rid of a sound for good.
	 *
	 * The game keeps track of the sounds it makes (`FlxG.sound.load()`, `FlxG.sound.play()`), and goes through them when the state changes:
	 * one that was destroyed on its own is still there for it to find, which crashes the game. This is what scripts get for `sound.destroy()`.
	 */
	public static function dispose(sound:FlxSound):Void
	{
		if(sound == null) return;

		var alive:Bool = false;
		@:privateAccess alive = (sound._transform != null);
		if(alive) sound.stop();

		forget(sound);
		if(alive) sound.destroy();
	}

	static function resolve(asset:Dynamic, music:Bool = false):Sound
	{
		if(asset == null) return null;
		if(Std.isOfType(asset, Sound)) return asset;

		var key:String = Std.string(asset);
		return music ? funkin.Paths.music(key) : funkin.Paths.sound(key);
	}

	/**
	 * Plays a sound once and gets rid of it.
	 */
	public static function playOnce(asset:Dynamic, volume:Float = 1, ?onComplete:Void->Void, ?onLoad:Void->Void):FlxSound
	{
		var sound:Sound = resolve(asset);
		if(sound == null) return null;

		var result:FlxSound = FlxG.sound.play(sound, volume, false, null, true, onComplete);
		if(onLoad != null) onLoad();
		return result;
	}

	public static function load(asset:Dynamic, volume:Float = 1, looped:Bool = false, autoDestroy:Bool = false, autoPlay:Bool = false, persist:Bool = false,
			?onComplete:Void->Void, ?onLoad:Void->Void):FlxSound
	{
		var sound:Sound = resolve(asset);
		if(sound == null) return null;

		// (one of its own instead of one of the game's recycled sounds: scripts keep these around, and use what only this class has)
		var result:FunkinSound = new FunkinSound();
		result.loadEmbedded(sound, looped, autoDestroy, onComplete);
		result.volume = volume;
		result.persist = persist;
		if(autoPlay) result.play();
		if(onLoad != null) onLoad();
		return result;
	}

	/**
	 * Changes the music, returns false if it's missing.
	 */
	public static function playMusic(key:String, ?params:Dynamic):Bool
	{
		var sound:Sound = resolve(key, true);
		if(sound == null) return false;

		var volume:Float = (params != null && params.startingVolume != null) ? params.startingVolume : 1;
		var looped:Bool = (params == null || params.loop != false);
		FlxG.sound.playMusic(sound, volume, looped);
		return true;
	}

	// (V-Slice loads parts of songs for Freeplay's previews in a queue, which scripts empty before opening a song; nothing waits here)
	public static function emptyPartialQueue():Void {}

	// A sound that was destroyed does nothing when it's played, paused or resumed, like V-Slice's: scripts destroy one that
	// couldn't be loaded and go on to play it (Vs Kapi's cutscenes with no music, Hairball's Pico mix)
	override public function play(ForceRestart:Bool = false, StartTime:Float = 0.0, ?EndTime:Float):FlxSound
	{
		if(!exists) return this;
		return super.play(ForceRestart, StartTime, EndTime);
	}

	override public function resume():FlxSound
	{
		if(!exists) return this;
		return super.resume();
	}

	override public function pause():FlxSound
	{
		if(!exists) return this;
		return super.pause();
	}

	// (and its volume can still be set, like on V-Slice's: a destroyed sound has no transform left to put it on)
	override function updateTransform():Void
	{
		if(_transform == null) return;
		super.updateTransform();
	}

	public static function stopAllAudio(musicToo:Bool = false):Void
	{
		for (sound in FlxG.sound.list.members)
			if(sound != null) sound.stop();
		if(musicToo && FlxG.sound.music != null) FlxG.sound.music.stop();
	}
}
