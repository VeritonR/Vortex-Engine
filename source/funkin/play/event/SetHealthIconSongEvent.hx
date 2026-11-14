package funkin.play.event;

import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice's "SetHealthIcon" event: the engine does it (see `backend.VSliceScripts.runBuiltInEvent()`). Scripts extend it to change it
 * (`super.handleEvent(data)` does the usual thing).
 */
class SetHealthIconSongEvent extends SongEvent
{
	public function new(?_:Dynamic)
	{
		super('SetHealthIcon');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.runBuiltInEvent(data);
		#end
	}

	override public function getTitle():String return 'Set Health Icon';
}
