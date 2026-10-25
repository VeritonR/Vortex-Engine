package backend;

import flixel.system.scaleModes.RatioScaleMode;

/**
 * How the game fits the window: flixel's own way of keeping its ratio, without putting the game's size back to the first one every
 * time the window changes. That's how V-Slice's does it while a state is open (`funkin.ui.FullScreenScaleMode`, waiting to measure
 * again until the next state), and its mods' scripts count on it to change the game's size for a song:
 *
 *     Application.current.window.width = 960;
 *     FlxG.width = 960; FlxG.height = 720;
 *     FlxG.resizeGame(960, 720);
 *
 * The first size comes back when another state opens (one that isn't a song), like on V-Slice.
 */
class GameScaleMode extends RatioScaleMode
{
	static var listening:Bool = false;

	public function new()
	{
		super();
		if(listening) return;
		listening = true;

		// (not for a song: on V-Slice it's the menus that measure again, PlayState isn't one of them, and a song's scripts can set the
		// size before it's opened)
		FlxG.signals.preStateCreate.add(function(state)
		{
			if(!Std.isOfType(state, states.PlayState) && Std.isOfType(FlxG.scaleMode, GameScaleMode))
				cast(FlxG.scaleMode, GameScaleMode).restoreSize();
		});
	}

	override public function onMeasure(Width:Int, Height:Int):Void
	{
		updateGameSize(Width, Height);
		updateDeviceSize(Width, Height);
		updateScaleOffset();
		updateGamePosition();
	}

	/**
	 * Puts the game's size back to the one it started with, if a script changed it.
	 */
	public function restoreSize():Void
	{
		if(FlxG.width == FlxG.initialWidth && FlxG.height == FlxG.initialHeight) return;

		var oldWidth:Int = FlxG.width;
		var oldHeight:Int = FlxG.height;
		@:privateAccess
		{
			FlxG.width = FlxG.initialWidth;
			FlxG.height = FlxG.initialHeight;
		}
		onMeasure(FlxG.stage.stageWidth, FlxG.stage.stageHeight);

		// the cameras of the new state were already made, with the size the game had (V-Slice makes them again after this)
		for (camera in FlxG.cameras.list)
			if(camera != null && camera.width == oldWidth && camera.height == oldHeight)
				camera.setSize(FlxG.width, FlxG.height);

		FlxG.signals.gameResized.dispatch(FlxG.stage.stageWidth, FlxG.stage.stageHeight);
	}
}
