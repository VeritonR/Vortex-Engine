package funkin.play.event;

import funkin.data.song.SongData.SongEventData;

/**
 * V-Slice's "ScrollSpeed" event. The engine turns the ones of the charts into Psych's "Change Scroll Speed" when it loads them; this
 * is the class for scripts that extend it, done like V-Slice's: the scroll speed tweened to `scroll` (times the song's own one
 * unless `absolute`) over `duration` steps, on the strumlines it says.
 */
class ScrollSpeedEvent extends SongEvent
{
	public function new(?_:Dynamic)
	{
		super('ScrollSpeed');
	}

	override public function handleEvent(data:SongEventData):Void
	{
		var game:funkin.play.PlayState = funkin.play.PlayState.instance;
		if(game == null || data == null) return;

		var scroll:Null<Float> = data.getFloat('scroll');
		if(scroll == null) scroll = 1;
		if(data.getBool('absolute') != true && states.PlayState.SONG != null) scroll *= states.PlayState.SONG.speed;

		var strumline:String = data.getString('strumline');
		var strumlines:Array<String> = switch(strumline)
		{
			case 'player': ['player'];
			case 'opponent': ['opponent'];
			default: ['player', 'opponent'];
		};

		var ease:String = data.getString('ease');
		var duration:Null<Float> = data.getFloat('duration');
		if(ease == 'INSTANT' || duration == null || duration <= 0)
		{
			game.tweenScrollSpeed(scroll, 0, null, strumlines);
			return;
		}
		var easeDir:String = data.getString('easeDir');
		var easeName:String = (ease == null || ease == 'linear') ? 'linear' : ease + ((easeDir != null) ? easeDir : SongEvent.DEFAULT_EASE_DIR);
		game.tweenScrollSpeed(scroll, duration * backend.Conductor.stepCrochet / 1000, psychlua.LuaUtils.getTweenEaseByString(easeName), strumlines);
	}

	override public function getTitle():String return 'Scroll Speed';
}
