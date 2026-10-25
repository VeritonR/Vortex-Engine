package funkin.data.event;

import funkin.data.song.SongData.SongEventData;
import funkin.play.event.SongEvent;

/**
 * Lets scripts run song events by hand, the scripted ones of the mod being played and the built-in ones the engine knows.
 */
class SongEventRegistry
{
	public static function getEvent(id:String):SongEvent
	{
		return backend.VSliceScripts.getSongEvent(id);
	}

	public static function listEventIds():Array<String>
	{
		return backend.VSliceScripts.listSongEvents();
	}

	public static function handleEvent(data:SongEventData):Void
	{
		backend.VSliceScripts.handleSongEvent(data);
	}

	public static function handleEvents(events:Array<SongEventData>):Void
	{
		for (event in events)
			handleEvent(event);
	}
}
