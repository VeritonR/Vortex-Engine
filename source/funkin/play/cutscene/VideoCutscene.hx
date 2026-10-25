package funkin.play.cutscene;

import flixel.util.FlxSignal;

/**
 * V-Slice's video cutscenes: `VideoCutscene.play(Paths.videos('name'))`. The video is played by the engine's own video cutscene,
 * and what happens when it ends depends on the kind it was given: the countdown (the default), the end of the song, or nothing.
 */
@:access(states.PlayState)
class VideoCutscene
{
	public static var onVideoStarted(default, null):FlxSignal = new FlxSignal();
	public static var onVideoPaused(default, null):FlxSignal = new FlxSignal();
	public static var onVideoResumed(default, null):FlxSignal = new FlxSignal();
	public static var onVideoRestarted(default, null):FlxSignal = new FlxSignal();
	public static var onVideoEnded(default, null):FlxSignal = new FlxSignal();

	static var cutsceneType:String = 'STARTING';
	static var onComplete:Void->Void = null;
	static var playing:Bool = false;

	static var game(get, never):states.PlayState;
	static inline function get_game():states.PlayState return states.PlayState.instance;

	// "mods/(mod)/videos/name.mp4" -> "name", the engine finds the file by its name
	static function getKey(filePath:Dynamic):String
	{
		var key:String = Std.string(filePath).replace('\\', '/');
		var folder:Int = key.lastIndexOf('videos/');
		if(folder > -1) key = key.substr(folder + 'videos/'.length);

		var colon:Int = key.indexOf(':');
		if(colon > -1) key = key.substr(colon + 1);

		var dot:Int = key.lastIndexOf('.');
		if(dot > key.lastIndexOf('/')) key = key.substr(0, dot);
		return key;
	}

	/**
	 * @param cutsceneType 	One of `CutsceneType`'s: STARTING (the countdown starts when it's over), ENDING (the song ends) or MIDSONG.
	 * @param onComplete 	What's done when it's over instead. Mods give it in the type's place too (`play(path, function() {...})`),
	 * 						expecting it to be called: what it does is all that happens then.
	 */
	public static function play(filePath:Dynamic, ?cutsceneType:Dynamic, ?onComplete:Dynamic):Void
	{
		if(game == null || filePath == null) return;
		if(Reflect.isFunction(cutsceneType))
		{
			if(onComplete == null) onComplete = cutsceneType;
			cutsceneType = null;
		}
		if(cutsceneType == null) cutsceneType = 'STARTING';

		VideoCutscene.cutsceneType = Std.string(cutsceneType);
		VideoCutscene.onComplete = Reflect.isFunction(onComplete) ? onComplete : null;

		var video = game.startVideo(getKey(filePath), cutsceneType == 'MIDSONG');
		if(video == null)
		{
			// there's no such video (the engine said so), or videos aren't supported: the song goes on as if it had been watched
			#if VIDEOS_ALLOWED
			new FlxTimer().start(0.1, function(_) finish());
			#end
			return;
		}

		playing = true;
		video.finishCallback = onVideoEnd;
		video.onSkip = onVideoEnd;
		onVideoStarted.dispatch();
	}

	static function onVideoEnd():Void
	{
		if(game != null)
		{
			game.videoCutscene = null;
			game.canPause = true;
			game.inCutscene = false;
		}
		finish();
	}

	static function finish():Void
	{
		playing = false;
		onVideoEnded.dispatch();

		var facade:funkin.play.PlayState = funkin.play.PlayState.instance;
		if(game == null || facade == null) return;

		var callback:Void->Void = onComplete;
		onComplete = null;
		if(callback != null)
		{
			try
			{
				callback();
			}
			catch(e:Dynamic)
			{
				trace('Error on the end of a video cutscene: $e');
			}
			return;
		}

		switch(cutsceneType)
		{
			case 'ENDING': facade.endSong(true);
			case 'MIDSONG':
			default: if(game.startingSong && !game.startedCountdown) game.startCountdown();
		}
	}

	public static function isPlaying():Bool
	{
		return playing && game != null && game.videoCutscene != null;
	}

	public static function pauseVideo():Void
	{
		if(!isPlaying()) return;

		#if VIDEOS_ALLOWED
		game.videoCutscene.pause();
		#end
		onVideoPaused.dispatch();
	}

	public static function resumeVideo():Void
	{
		if(!isPlaying()) return;

		#if VIDEOS_ALLOWED
		game.videoCutscene.resume();
		#end
		onVideoResumed.dispatch();
	}

	public static function hideVideo():Void
	{
		if(isPlaying()) game.videoCutscene.visible = false;
	}

	public static function showVideo():Void
	{
		if(isPlaying()) game.videoCutscene.visible = true;
	}

	public static function restartVideo():Void
	{
		onVideoRestarted.dispatch();
	}

	/**
	 * Ends the video before its time.
	 */
	public static function finishVideo(?transitionTime:Float = 0.5):Void
	{
		if(!isPlaying()) return;

		var video = game.videoCutscene;
		game.remove(video);
		video.destroy();
		onVideoEnd();
	}

	public static function destroyVideo():Void
	{
		if(!isPlaying()) return;

		var video = game.videoCutscene;
		game.videoCutscene = null;
		game.remove(video);
		video.destroy();
		playing = false;
		onComplete = null;
	}

	/**
	 * What scripts added to the signals goes away with their song.
	 */
	public static function reset():Void
	{
		for (signal in [onVideoStarted, onVideoPaused, onVideoResumed, onVideoRestarted, onVideoEnded])
			signal.removeAll();
		playing = false;
		onComplete = null;
	}
}
