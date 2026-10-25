package funkin.util;

// V-Slice's sequences: lists of things to do at given times, `{time: (seconds), callback: (function)}`.
// Scripts import them as `funkin.util.Sequence` and `funkin.util.SongSequence`.

/**
 * A sequence that goes by the clock, starting when it's made: one timer that goes from each event to the next, like V-Slice's.
 */
class Sequence
{
	var timer:FlxTimer = new FlxTimer();
	var events:Array<Dynamic> = [];

	// How many of the events were already done
	var eventCount:Int = 0;

	/**
	 * What the times of the events are multiplied by, for the sequences that count in frames or in beats.
	 */
	public var multiplier:Float = 1;

	// If it gets rid of itself when it's over
	public var autoDestroy:Bool = true;

	/**
	 * The event that's coming next, null when the sequence is over.
	 */
	public var currentEvent(get, never):Dynamic;
	function get_currentEvent():Dynamic return events[eventCount];

	/**
	 * If the sequence is going. Scripts set it to pause the sequence and to let it go on (with the game, for one).
	 */
	public var running(get, set):Bool;
	function get_running():Bool return completed ? false : (timer.active && !timer.finished);
	function set_running(value:Bool):Bool
	{
		if(completed) return false;
		return timer.active = value;
	}

	public var completed(get, never):Bool;
	function get_completed():Bool return eventCount >= events.length;

	public function new(events:Array<Dynamic>, mult:Float = 1, start:Bool = true, autoDestroy:Bool = true)
	{
		// (the ones without something to do would only be waited for)
		if(events != null) this.events = [for (event in events) if(event != null && event.callback != null) event];
		if(this.events.length == 0) return;

		multiplier = Math.max(0, mult);
		this.autoDestroy = autoDestroy;

		// negative times count as positive ones, like on a timer
		for (event in this.events) event.time = Math.abs(event.time);
		this.events.sort((a, b) -> Reflect.compare(a.time, b.time));

		timer.start(currentEvent.time * multiplier, onTimer);
		running = start;
	}

	function onTimer(_):Void
	{
		var event:Dynamic = currentEvent;
		if(event == null) return;

		eventCount++;
		event.callback();

		// (what was just done can have stopped it, or started it over)
		if(eventCount < 1 || events.length < 1) return;
		if(!completed) timer.reset((currentEvent.time - events[eventCount - 1].time) * multiplier);
		else if(autoDestroy) destroy();
	}

	/**
	 * Starts the sequence over from its first event.
	 */
	public function start():Void
	{
		if(events.length == 0) return;

		eventCount = 0;
		timer.start(currentEvent.time * multiplier, onTimer);
	}

	public function restart():Void start();

	/**
	 * Leaves out what's left of the sequence.
	 */
	public function stop():Void
	{
		eventCount = events.length;
		timer.cancel();
	}

	public function destroy():Void
	{
		timer.cancel();
		events = [];
		eventCount = 0;
	}
}

/**
 * A sequence that goes by the song's position: an event with the time 1.5 happens when the song gets to a second and a half
 * after the sequence's `startTime`, negative times being the countdown.
 */
class SongSequence
{
	static var active:Array<SongSequence> = [];

	/**
	 * Called every frame while a song is being played.
	 */
	public static function updateAll():Void
	{
		if(active.length < 1) return;

		for (sequence in active.copy())
			sequence.onUpdate();
	}

	public static function clearAll():Void
	{
		active = [];
	}

	/**
	 * Position of the song (in milliseconds) the times of the events are counted from.
	 */
	public var startTime:Float = 0;

	var events:Array<Dynamic> = [];
	var _running:Bool = false;

	public function new(events:Array<Dynamic>, mult:Float = 1, start:Bool = true)
	{
		if(events == null || events.length < 1) return;

		mult = Math.max(0, mult);
		for (event in events)
		{
			if(event == null) continue;

			event.time = event.time * mult * 1000;
			this.events.push(event);
		}
		haxe.ds.ArraySort.sort(this.events, function(a:Dynamic, b:Dynamic):Int
		{
			var timeA:Float = a.time;
			var timeB:Float = b.time;
			return (timeA < timeB) ? -1 : ((timeA > timeB) ? 1 : 0);
		});

		running = start;
		active.push(this);
	}

	function onUpdate():Void
	{
		if(!running) return;

		var position:Float = backend.Conductor.songPosition;
		while(events.length > 0 && events[0].time + startTime <= position)
		{
			var event:Dynamic = events.shift();
			if(event.callback != null) event.callback();
		}
		if(completed) destroy();
	}

	public var running(get, set):Bool;
	function get_running():Bool return _running && !completed;
	function set_running(value:Bool):Bool
	{
		if(completed) return false;

		// stopping keeps how far it went, starting again goes on from there
		if(value != _running) startTime = backend.Conductor.songPosition - startTime;
		return _running = value;
	}

	public var completed(get, never):Bool;
	function get_completed():Bool return events.length < 1;

	public function destroy():Void
	{
		active.remove(this);
		events = [];
		_running = false;
	}
}
