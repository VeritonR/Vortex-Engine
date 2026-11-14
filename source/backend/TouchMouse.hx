package backend;

import flixel.FlxBasic;
#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end

/**
 * The mouse on a touch screen, during songs: the last finger that touched the screen.
 *
 * The phone moves the mouse with the first finger only. In a song that's the one holding an arrow, so a tap somewhere else (a
 * mod's popups to click, a button of its own) was never a click. Here every new touch is a click where it was, held while that
 * finger stays, and a finger that's only holding the arrows doesn't leave the mouse pressed. Scripts that ask the mouse
 * (`FlxG.mouse.justPressed`, `mouseClicked()`, `getMouseX()`...) get the tap.
 *
 * It's a plugin of flixel's: it runs after the input is read and before the state's update, where scripts look at it.
 */
class TouchMouse extends FlxBasic
{
	static var added:Bool = false;

	public static function init():Void
	{
		#if (mobile && FLX_TOUCH && FLX_MOUSE)
		if(added) return;
		added = true;
		FlxG.plugins.addPlugin(new TouchMouse());
		#end
	}

	#if (FLX_TOUCH && FLX_MOUSE)
	// The finger the mouse is (-1: none, -2: it was lifted on the last frame, QUICK_TAP: a tap that's let go on the next frame)
	var following:Int = -1;
	static inline final QUICK_TAP:Int = -3;

	// (the fingers seen down already: one that's let go without having been seen was a quick tap)
	var seen:Map<Int, Bool> = [];

	@:access(flixel.input.FlxPointer)
	@:access(flixel.input.mouse.FlxMouse)
	override function update(elapsed:Float):Void
	{
		if(!Std.isOfType(FlxG.state, states.PlayState) || FlxG.touches == null)
		{
			following = -1;
			return;
		}

		var button = FlxG.mouse._leftButton;

		// (a tap that was over before the frame saw it: clicked on this frame, let go on the next)
		if(following == QUICK_TAP)
		{
			setState(button, JUST_RELEASED);
			following = -2;
			return;
		}

		var newest:FlxTouch = null;
		var quickTap:FlxTouch = null;
		for (touch in FlxG.touches.list)
		{
			if(touch == null) continue;
			if(touch.justPressed) newest = touch;
			// a finger that touched and lifted between two frames (a quick tap on a slow phone): the frame only sees it lifted
			else if(touch.justReleased && !seen.exists(touch.touchPointID)) quickTap = touch;
			if(touch.pressed) seen.set(touch.touchPointID, true);
		}
		for (id in [for (id in seen.keys()) id])
			if(FlxG.touches.getByID(id) == null) seen.remove(id);

		if(newest != null)
		{
			following = newest.touchPointID;
			moveTo(newest);
			setState(button, JUST_PRESSED);
			return;
		}
		if(quickTap != null)
		{
			following = QUICK_TAP;
			moveTo(quickTap);
			setState(button, JUST_PRESSED);
			return;
		}

		if(following >= 0)
		{
			var touch:FlxTouch = FlxG.touches.getByID(following);
			if(touch != null && touch.pressed)
			{
				moveTo(touch);
				setState(button, PRESSED);
			}
			else
			{
				if(touch != null) moveTo(touch);
				setState(button, JUST_RELEASED);
				following = -2;
			}
			return;
		}

		following = -1;
		setState(button, RELEASED);
	}

	@:access(flixel.input.FlxPointer)
	static function moveTo(touch:FlxTouch):Void
	{
		var mouse = FlxG.mouse;
		mouse._globalScreenX = touch._globalScreenX;
		mouse._globalScreenY = touch._globalScreenY;
		mouse.updatePositions();
	}

	static inline function setState(button:flixel.input.FlxInput<Int>, state:flixel.input.FlxInput.FlxInputState):Void
	{
		button.last = button.current;
		button.current = state;
	}
	#end
}
