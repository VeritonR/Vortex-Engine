package funkin.play.event;

import funkin.data.song.SongData.SongEventData;

/**
 * What V-Slice song event scripts extend: `handleEvent()` runs when an event with its id comes up on the chart.
 */
class SongEvent extends funkin.modding.ScriptedBase
{
	// What V-Slice's own events use for the easing of their tweens, which the ones of mods are copied from
	public static var DEFAULT_EASE:String = 'linear';
	public static var DEFAULT_EASE_DIR:String = 'In';
	public static var EASE_TYPE_DIR_REGEX:EReg = ~/(In|Out|InOut)$/i;

	public var id:String;
	public var processOldEvents:Bool = false;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
		if(params != null && params.processOldEvents == true) processOldEvents = true;
	}

	public function handleEvent(data:SongEventData):Void {}

	public function getEventSchema():Dynamic
	{
		return null;
	}

	public function getIconPath():String
	{
		return 'ui/chart-editor/events/default';
	}

	public function getTitle():String
	{
		return id;
	}

	public function toString():String
	{
		return 'SongEvent($id)';
	}
}
