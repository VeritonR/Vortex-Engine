package funkin.ui.debug.results;

/**
 * V-Slice's tool to try out its results screen, opened from its debug menu (see `funkin.ui.debug.DebugMenuSubState`, which the
 * engine doesn't have). It closes right away if a script opens it anyway.
 */
class ResultsDebugSubState extends backend.MusicBeatSubstate
{
	override function create():Void
	{
		super.create();
		close();
	}
}
