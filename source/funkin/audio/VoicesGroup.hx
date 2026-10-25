package funkin.audio;

/**
 * The voices of the song as V-Slice scripts know them (`PlayState.instance.vocals`): one thing with the player's and the opponent's,
 * which are two separate sounds on Psych.
 */
@:access(states.PlayState)
class VoicesGroup
{
	var game:states.PlayState;

	public function new(game:states.PlayState)
	{
		this.game = game;
	}

	public var playerVoices(get, never):FlxSound;
	function get_playerVoices():FlxSound return game.vocals;

	public var opponentVoices(get, never):FlxSound;
	function get_opponentVoices():FlxSound return game.opponentVocals;

	public var members(get, never):Array<FlxSound>;
	function get_members():Array<FlxSound> return [for (sound in [game.vocals, game.opponentVocals]) if(sound != null) sound];

	public var playerVolume(get, set):Float;
	function get_playerVolume():Float return (game.vocals != null) ? game.vocals.volume : 1;
	function set_playerVolume(value:Float):Float
	{
		if(game.vocals != null) game.vocals.volume = value;
		return value;
	}

	// (songs with a single file for both voices only have the player's sound)
	public var opponentVolume(get, set):Float;
	function get_opponentVolume():Float return (game.opponentVocals != null) ? game.opponentVocals.volume : 1;
	function set_opponentVolume(value:Float):Float
	{
		if(game.opponentVocals != null) game.opponentVocals.volume = value;
		return value;
	}

	public var volume(get, set):Float;
	function get_volume():Float return playerVolume;
	function set_volume(value:Float):Float
	{
		playerVolume = value;
		opponentVolume = value;
		return value;
	}

	public var time(get, set):Float;
	function get_time():Float return (game.vocals != null) ? game.vocals.time : 0;
	function set_time(value:Float):Float
	{
		for (sound in members)
			sound.time = value;
		return value;
	}

	public var pitch(get, set):Float;
	function get_pitch():Float return #if FLX_PITCH (game.vocals != null) ? game.vocals.pitch : #end 1;
	function set_pitch(value:Float):Float
	{
		#if FLX_PITCH
		for (sound in members)
			sound.pitch = value;
		#end
		return value;
	}

	public var playing(get, never):Bool;
	function get_playing():Bool return (game.vocals != null && game.vocals.playing);

	public var length(get, never):Float;
	function get_length():Float return (game.vocals != null) ? game.vocals.length : 0;

	public function play(forceRestart:Bool = false, startTime:Float = 0.0, ?endTime:Float):VoicesGroup
	{
		for (sound in members)
			sound.play(forceRestart, startTime, endTime);
		return this;
	}

	public function pause():VoicesGroup
	{
		for (sound in members)
			sound.pause();
		return this;
	}

	public function resume():VoicesGroup
	{
		for (sound in members)
			sound.resume();
		return this;
	}

	public function stop():VoicesGroup
	{
		for (sound in members)
			sound.stop();
		return this;
	}

	public function fadeOut(duration:Float = 1, ?to:Float = 0, ?onComplete:FlxTween->Void):Void
	{
		for (sound in members)
			sound.fadeOut(duration, to, onComplete);
	}

	public function fadeIn(duration:Float = 1, from:Float = 0, to:Float = 1, ?onComplete:FlxTween->Void):Void
	{
		for (sound in members)
			sound.fadeIn(duration, from, to, onComplete);
	}
}
