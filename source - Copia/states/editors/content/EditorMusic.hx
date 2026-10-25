package states.editors.content;

import flixel.FlxBasic;
import flixel.sound.FlxSound;

/**
 * The music the editors play while they're open, V-Slice's "Artistic Expression" (`chartEditorLoop`).
 *
 * Like V-Slice's chart editor, it waits a while and then fades in slowly, and it goes quiet while something else is being listened to
 * (the song of the chart, a preview...): `busy` says when that is. It counts its beats too (`onBeat`), for what dances to it.
 * It can be turned off for every editor (`enabled`, saved): "M" on the editors menu, or the chart editor's "View" menu.
 *
 * It's added to the state like anything else, and goes away with it.
 */
class EditorMusic extends FlxBasic
{
	public static inline final KEY:String = 'chartEditorLoop/chartEditorLoop';
	public static inline final BPM:Float = 137;

	public static var enabled(get, set):Bool;
	static function get_enabled():Bool
		return FlxG.save.data.editorMusic != false;
	static function set_enabled(value:Bool):Bool
	{
		FlxG.save.data.editorMusic = value;
		FlxG.save.flush();
		return value;
	}

	/**
	 * When it says so the music stops, and waits again from the start once it doesn't. Null is never.
	 */
	public var busy:Void->Bool = null;

	/**
	 * Called on each of the music's beats while it plays, with the beat's number.
	 */
	public var onBeat:Int->Void = null;

	public var sound(default, null):FlxSound = null;

	var delay:Float;
	var fadeTime:Float;
	var waited:Float = 0;
	var lastBeat:Int = -1;

	/**
	 * @param delay     Seconds before it starts (V-Slice's chart editor waits 10).
	 * @param fadeTime  Seconds it takes to get to its full volume.
	 */
	public function new(delay:Float = 10, fadeTime:Float = 20)
	{
		super();
		this.delay = delay;
		this.fadeTime = fadeTime;
		visible = false;

		if(Paths.fileExists('music/$KEY.${Paths.SOUND_EXT}', SOUND))
		{
			sound = new FlxSound().loadEmbedded(Paths.music(KEY), true);
			sound.volume = 0;
			FlxG.sound.list.add(sound);
		}
	}

	public var playing(get, never):Bool;
	inline function get_playing():Bool
		return sound != null && sound.playing;

	/**
	 * Stops it, to start again after the wait.
	 */
	public function stop():Void
	{
		waited = 0;
		lastBeat = -1;
		if(sound != null && sound.playing)
		{
			if(sound.fadeTween != null) sound.fadeTween.cancel();
			sound.pause();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(sound == null) return;

		if(!enabled || (busy != null && busy()))
		{
			stop();
			return;
		}

		if(!sound.playing)
		{
			waited += elapsed;
			if(waited < delay) return;

			sound.volume = 0;
			sound.play();
			sound.fadeIn(fadeTime, 0, 0.8);
		}

		if(onBeat != null)
		{
			var beat:Int = Math.floor(sound.time / (60000 / BPM));
			if(beat != lastBeat)
			{
				lastBeat = beat;
				onBeat(beat);
			}
		}
	}

	override function destroy()
	{
		if(sound != null)
		{
			FlxG.sound.list.remove(sound, true);
			sound.destroy();
			sound = null;
		}
		busy = null;
		onBeat = null;
		super.destroy();
	}
}
