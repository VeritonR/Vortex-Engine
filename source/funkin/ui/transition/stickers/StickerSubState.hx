package funkin.ui.transition.stickers;

import flixel.FlxState;

/**
 * What V-Slice scripts go to another screen with, with the stickers covering the way (IndieCross' game overs):
 *
 *     openSubState(new StickerSubState({targetState: (sticker) -> FreeplayState.build(null, sticker), stickerPack: 'standard-bf'}));
 *
 * The engine has its own sticker transition (`backend.StickerTransition`), with the same sticker packs: this hands it the screen and
 * the pack. Without a screen it goes to Freeplay, like V-Slice's.
 */
class StickerSubState extends backend.MusicBeatSubstate
{
	var targetState:Dynamic = null;
	var stickerPackId:String = null;
	var started:Bool = false;

	public function new(?params:Dynamic)
	{
		super();
		if(params != null)
		{
			targetState = Reflect.field(params, 'targetState');
			stickerPackId = Reflect.field(params, 'stickerPack');
		}
	}

	override function create():Void
	{
		super.create();
		start();
	}

	function start():Void
	{
		if(started) return;
		started = true;

		var target:FlxState = null;
		if(targetState != null)
		{
			var made:Dynamic = Reflect.isFunction(targetState) ? Reflect.callMethod(null, targetState, [this]) : targetState;
			target = Std.downcast(made, FlxState);
		}
		if(target == null) target = new states.FreeplayState();

		backend.StickerTransition.prepare((stickerPackId != null && stickerPackId.length > 0) ? stickerPackId : null);
		backend.StickerTransition.switchState(target);
	}
}
