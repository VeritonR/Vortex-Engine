package funkin.play.event;

import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice's "PlayAnimation" event: the engine does it (see `backend.VSliceScripts.runBuiltInEvent()`). Scripts extend it to change it
 * (`super.handleEvent(data)` does the usual thing).
 */
class PlayAnimationSongEvent extends SongEvent
{
	public function new(?_:Dynamic)
	{
		super('PlayAnimation');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.runBuiltInEvent(data);
		#end
	}

	override public function getTitle():String return 'Play Animation';
}
