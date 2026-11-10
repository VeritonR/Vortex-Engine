package backend;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.geom.Matrix;

/**
 * The "Supersampling" option (Graphics), like a graphics card's DSR: the game is drawn on a texture bigger than the window
 * (1.5 or 2 times), which is then shown at the window's size, smoothed. Big images shown small (stages, atlases) stop shimmering
 * and the edges of everything come out smoother. It costs the graphics card that much more drawing, so it's off by default.
 *
 * The game itself keeps working the same: it's hidden from the window and drawn on the texture after each frame (`postDraw`),
 * the mouse still goes to it.
 */
class Supersampling
{
	/**
	 * How much bigger than the window the game is drawn: 1 is off.
	 */
	public static var factor(default, null):Float = 1;

	static var view:Bitmap = null;
	static var buffer:BitmapData = null;
	static var matrix:Matrix = new Matrix();
	static var listening:Bool = false;

	/**
	 * Turns it on or off, from the option's value: "Off", "1.5x" or "2x".
	 */
	public static function apply(value:String):Void
	{
		var wanted:Float = switch(value)
		{
			case '1.5x': 1.5;
			case '2x': 2;
			default: 1;
		}
		if(FlxG.game == null || FlxG.stage == null) return;

		factor = wanted;
		if(factor <= 1) stop();
		listen();
	}

	/**
	 * Starts drawing the game the way this does, on the frames that need it: with the option on, or when the Widescreen option
	 * fills the bars around the game (see GameScaleMode.sidesWanted()).
	 */
	public static function listen():Void
	{
		if(listening) return;
		listening = true;
		FlxG.signals.postDraw.add(render);
	}

	static function stop():Void
	{
		if(buffer == null && (view == null || view.parent == null)) return;
		if(view != null && view.parent != null) view.parent.removeChild(view);
		if(buffer != null) buffer.dispose();
		buffer = null;
		if(view != null) view.bitmapData = null;
		if(FlxG.game != null) FlxG.game.visible = true;
	}

	// After the game has made its frame: drawn on the texture, the texture shown in its place
	static function render():Void
	{
		var sides:Bool = GameScaleMode.sidesWanted();
		if(factor <= 1 && !sides)
		{
			stop();
			return;
		}
		var factor:Float = Math.max(1, Supersampling.factor);

		var stage = FlxG.stage;
		var width:Int = Math.ceil(stage.stageWidth * factor);
		var height:Int = Math.ceil(stage.stageHeight * factor);
		if(width < 1 || height < 1 || stage.context3D == null) return; //(minimized, or not drawn by the graphics card)

		if(buffer == null || buffer.width != width || buffer.height != height)
		{
			if(buffer != null) buffer.dispose();
			try
			{
				buffer = new BitmapData(width, height, false, 0xFF000000);
				buffer.disposeImage(); //(on the graphics card only: that's where it's drawn on)
			}
			catch(e:Dynamic)
			{
				// too big for the graphics card: back to the usual drawing
				trace('Supersampling: a texture of ${width}x$height could not be made, it is turned off ($e)');
				Supersampling.factor = 1;
				stop();
				return;
			}
		}

		if(view == null)
		{
			view = new Bitmap();
			view.smoothing = true;
		}
		if(view.bitmapData != buffer) view.bitmapData = buffer;
		view.smoothing = true;
		view.scaleX = view.scaleY = 1 / factor;
		var holder = FlxG.game.parent;
		if(holder == null) return;
		if(view.parent != holder)
		{
			// right over the game, where it is (in Main): what's put over the game (the FPS counter, the chat...) stays over it
			if(view.parent != null) view.parent.removeChild(view);
			holder.addChildAt(view, holder.getChildIndex(FlxG.game) + 1);
		}

		buffer.fillRect(buffer.rect, 0xFF000000);
		if(sides) GameScaleMode.drawSidesOn(buffer, factor); //(the Widescreen option's, behind the game)
		matrix.identity();
		matrix.scale(FlxG.game.scaleX, FlxG.game.scaleY); //(zoomed in by a tutorial, see backend.Tutorial)
		matrix.translate(FlxG.game.x, FlxG.game.y);
		matrix.scale(factor, factor);
		FlxG.game.visible = true;
		buffer.draw(FlxG.game, matrix, null, null, null, true);
		FlxG.game.visible = false; //(the window shows the texture instead)
		if(sides) GameScaleMode.takeSidesFrom(buffer, factor);
	}
}
