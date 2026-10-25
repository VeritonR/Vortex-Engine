package funkin;

import flixel.util.FlxSignal;

/**
 * V-Slice's Conductor. `Conductor.instance` is the song's: Psych's own Conductor, with the names V-Slice gives to things.
 *
 * Scripts can also make one of their own (`new Conductor()`) to keep the time of something else, like the music of a cutscene:
 * those are given a tempo (`forceBPM()` or `mapTimeChanges()`) and told where the music is at every frame (`update(music.time)`),
 * and tell back when a step, a beat or a measure goes by (`onStepHit`, `onBeatHit` and `onMeasureHit`).
 */
class Conductor
{
	public static var instance:Conductor = new Conductor();

	/**
	 * Dispatched with the steps, beats and measures of the song being played.
	 */
	public static var stepHit(default, null):FlxSignal = new FlxSignal();
	public static var beatHit(default, null):FlxSignal = new FlxSignal();
	public static var measureHit(default, null):FlxSignal = new FlxSignal();

	public var onStepHit(default, null):FlxSignal = new FlxSignal();
	public var onBeatHit(default, null):FlxSignal = new FlxSignal();
	public var onMeasureHit(default, null):FlxSignal = new FlxSignal();

	public var instrumentalOffset:Float = 0;
	public var formatOffset:Float = 0;

	// For the ones scripts make
	var ownPosition:Float = 0;
	var ownChanges:Array<{time:Float, bpm:Float}> = null; //null until it's given a tempo
	var forcedBpm:Null<Float> = null;
	var lastStep:Int = -1;
	var lastBeat:Int = -1;
	var lastMeasure:Int = -1;

	var isSong(get, never):Bool;
	inline function get_isSong():Bool return this == instance;

	public function new() {}

	// ------------------------------------------------------------------------------------------
	// The song's own
	// ------------------------------------------------------------------------------------------

	/**
	 * Called by the engine with each step, beat and section of the song being played.
	 */
	public static function dispatchSongStep():Void
	{
		instance.onStepHit.dispatch();
		stepHit.dispatch();
	}

	public static function dispatchSongBeat():Void
	{
		instance.onBeatHit.dispatch();
		beatHit.dispatch();
	}

	public static function dispatchSongMeasure():Void
	{
		instance.onMeasureHit.dispatch();
		measureHit.dispatch();
	}

	/**
	 * Forgets what scripts were listening to, they don't outlive their song.
	 */
	public static function reset():Void
	{
		for (signal in [stepHit, beatHit, measureHit, instance.onStepHit, instance.onBeatHit, instance.onMeasureHit])
			signal.removeAll();
	}

	// ------------------------------------------------------------------------------------------
	// Tempo
	// ------------------------------------------------------------------------------------------

	/**
	 * A single tempo for everything, null to go back to the ones `mapTimeChanges()` gave. The song's own tempo isn't changed from here.
	 */
	public function forceBPM(?bpm:Float):Void
	{
		if(isSong) return;
		forcedBpm = (bpm != null && bpm > 0) ? bpm : null;
	}

	/**
	 * The tempo changes of a music, as its data file has them: `[{t: (milliseconds), bpm: (tempo)}, ...]`.
	 */
	public function mapTimeChanges(songTimeChanges:Array<Dynamic>):Void
	{
		if(isSong || songTimeChanges == null) return;

		ownChanges = [];
		for (change in songTimeChanges)
		{
			if(change == null) continue;

			var time:Dynamic = (change.t != null) ? change.t : change.timeStamp;
			var bpm:Dynamic = change.bpm;
			if(Std.isOfType(bpm, Float) && bpm > 0) ownChanges.push({time: Std.isOfType(time, Float) ? time : 0, bpm: bpm});
		}
		ownChanges.sort((a, b) -> (a.time < b.time) ? -1 : ((a.time > b.time) ? 1 : 0));
		if(ownChanges.length > 0) ownChanges[0].time = Math.min(ownChanges[0].time, 0);
		else ownChanges = null;
	}

	function ownBpmAt(ms:Float):Float
	{
		if(forcedBpm != null) return forcedBpm;
		if(ownChanges == null) return 100;

		var bpm:Float = ownChanges[0].bpm;
		for (change in ownChanges)
		{
			if(change.time > ms) break;
			bpm = change.bpm;
		}
		return bpm;
	}

	function ownStepsAt(ms:Float):Float
	{
		if(forcedBpm != null || ownChanges == null) return ms / (15000 / ownBpmAt(0));

		var steps:Float = 0;
		for (index => change in ownChanges)
		{
			var end:Float = (index + 1 < ownChanges.length) ? ownChanges[index + 1].time : Math.POSITIVE_INFINITY;
			if(index > 0 && ms <= change.time) break;

			steps += (Math.min(ms, end) - change.time) / (15000 / change.bpm);
		}
		return steps;
	}

	function ownTimeOfStep(stepTime:Float):Float
	{
		if(forcedBpm != null || ownChanges == null) return stepTime * (15000 / ownBpmAt(0));

		var steps:Float = 0;
		for (index => change in ownChanges)
		{
			var stepLength:Float = 15000 / change.bpm;
			if(index + 1 >= ownChanges.length) return change.time + (stepTime - steps) * stepLength;

			var segment:Float = (ownChanges[index + 1].time - change.time) / stepLength;
			if(stepTime < steps + segment) return change.time + (stepTime - steps) * stepLength;
			steps += segment;
		}
		return 0;
	}

	/**
	 * Tells a Conductor made by a script where its music is at, in milliseconds (the game's music when given nothing).
	 * The song's own is kept up to date by the engine.
	 */
	public function update(?songPos:Float, applyOffsets:Bool = true, forceDispatch:Bool = false):Void
	{
		if(isSong) return;

		if(songPos == null) songPos = (FlxG.sound.music != null) ? FlxG.sound.music.time : 0;
		ownPosition = songPos;

		var step:Int = Math.floor(ownStepsAt(songPos));
		var beat:Int = Math.floor(step / 4);
		var measure:Int = Math.floor(step / 16);

		var stepChanged:Bool = (step != lastStep);
		var beatChanged:Bool = (beat != lastBeat);
		var measureChanged:Bool = (measure != lastMeasure);
		lastStep = step;
		lastBeat = beat;
		lastMeasure = measure;

		if(stepChanged || forceDispatch) onStepHit.dispatch();
		if(beatChanged || forceDispatch) onBeatHit.dispatch();
		if(measureChanged || forceDispatch) onMeasureHit.dispatch();
	}

	// ------------------------------------------------------------------------------------------
	// Values
	// ------------------------------------------------------------------------------------------

	public var songPosition(get, never):Float;
	function get_songPosition():Float return isSong ? backend.Conductor.songPosition : ownPosition;

	public var bpm(get, never):Float;
	function get_bpm():Float return isSong ? backend.Conductor.bpm : ownBpmAt(ownPosition);

	public var startingBPM(get, never):Float;
	function get_startingBPM():Float
	{
		if(!isSong) return ownBpmAt(0);
		return (states.PlayState.SONG != null) ? states.PlayState.SONG.bpm : backend.Conductor.bpm;
	}

	public var beatLengthMs(get, never):Float;
	function get_beatLengthMs():Float return isSong ? backend.Conductor.crochet : 60000 / bpm;

	public var stepLengthMs(get, never):Float;
	function get_stepLengthMs():Float return isSong ? backend.Conductor.stepCrochet : 15000 / bpm;

	public var measureLengthMs(get, never):Float;
	function get_measureLengthMs():Float return beatLengthMs * 4;

	public var timeSignatureNumerator(get, never):Int;
	function get_timeSignatureNumerator():Int return 4;

	public var timeSignatureDenominator(get, never):Int;
	function get_timeSignatureDenominator():Int return 4;

	public var beatsPerMeasure(get, never):Float;
	function get_beatsPerMeasure():Float return 4;

	public var stepsPerMeasure(get, never):Int;
	function get_stepsPerMeasure():Int return 16;

	public var currentStepTime(get, never):Float;
	function get_currentStepTime():Float return isSong ? backend.Conductor.getStep(backend.Conductor.songPosition) : ownStepsAt(ownPosition);

	public var currentBeatTime(get, never):Float;
	function get_currentBeatTime():Float return currentStepTime / 4;

	public var currentMeasureTime(get, never):Float;
	function get_currentMeasureTime():Float return currentStepTime / 16;

	public var currentStep(get, never):Int;
	function get_currentStep():Int return Math.floor(currentStepTime);

	public var currentBeat(get, never):Int;
	function get_currentBeat():Int return Math.floor(currentStep / 4);

	public var currentMeasure(get, never):Int;
	function get_currentMeasure():Int return Math.floor(currentStep / 16);

	public function getTimeInSteps(ms:Float):Float
	{
		return isSong ? backend.Conductor.getStep(ms) : ownStepsAt(ms);
	}

	public function getStepTimeInMs(stepTime:Float):Float
	{
		return isSong ? stepTime * backend.Conductor.stepCrochet : ownTimeOfStep(stepTime);
	}

	public function getBeatTimeInMs(beatTime:Float):Float
	{
		return isSong ? beatTime * backend.Conductor.crochet : ownTimeOfStep(beatTime * 4);
	}

	public function getMeasureTimeInMs(measureTime:Float):Float
	{
		return isSong ? measureTime * backend.Conductor.crochet * 4 : ownTimeOfStep(measureTime * 16);
	}

	public function getTimeInMeasures(ms:Float):Float
	{
		return getTimeInSteps(ms) / 16;
	}
}
