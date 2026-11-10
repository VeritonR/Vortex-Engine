package backend;

import flixel.FlxCamera;
import flixel.system.scaleModes.RatioScaleMode;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;

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
			wideCamera = null;
			menuCamera = null;
			if(!Std.isOfType(state, states.PlayState) && Std.isOfType(FlxG.scaleMode, GameScaleMode))
				cast(FlxG.scaleMode, GameScaleMode).restoreSize();
		});
		FlxG.signals.gameResized.add(function(_, _)
		{
			fitWideCamera();
			fitMenuCamera();
		});
		Supersampling.listen(); //(where the bars are filled)
	}

	// ------------------------------------------------------------------------------------------
	// Widescreen
	// ------------------------------------------------------------------------------------------

	/**
	 * The world camera of the song being played, which fills the whole window with the Widescreen option (Graphics), instead of
	 * leaving black bars where the window is wider (or taller) than 16:9. Only that camera grows: the game stays 1280x720 for
	 * everything else, so the HUD, the menus and the scripts see the same screen as always, in the middle.
	 */
	static var wideCamera:FlxCamera = null;

	// How much the camera goes past the game on each side, in the game's pixels
	static var padX:Float = 0;
	static var padY:Float = 0;

	/**
	 * Makes a song's world camera fill the window, if the option is on. Called by PlayState once it made its cameras.
	 */
	public static function widen(camera:FlxCamera):Void
	{
		wideCamera = camera;
		fitWideCamera();
	}

	static function fitWideCamera():Void
	{
		var camera:FlxCamera = wideCamera;
		if(camera == null || FlxG.scaleMode == null || !FlxG.cameras.list.contains(camera)) return;

		var scale = FlxG.scaleMode.scale;
		var on:Bool = ClientPrefs.data.wideScreen && scale.x > 0 && scale.y > 0;
		padX = on ? Math.max(0, Math.ceil((FlxG.stage.stageWidth / scale.x - FlxG.width) / 2)) : 0;
		padY = on ? Math.max(0, Math.ceil((FlxG.stage.stageHeight / scale.y - FlxG.height) / 2)) : 0;

		// (where it's looking stays the same: the camera follows its target from its middle, and that's where it was)
		camera.setPosition(-padX, -padY);
		camera.setSize(Std.int(FlxG.width + padX * 2), Std.int(FlxG.height + padY * 2));

		// (the area it keeps its target in is worked out from its size when it starts following it)
		if(camera.target != null) camera.follow(camera.target, camera.style, camera.followLerp);
	}

	/**
	 * Called by the world camera after it drew its flashes and fades: where it goes past the game, it also gets the ones of
	 * the cameras over it, which only cover the middle (a song that fades the HUD to black at its end, a white flash). And the
	 * pause menu's darkness.
	 */
	public static function coverSides(camera:FlxCamera):Void
	{
		if(camera != wideCamera || (padX <= 0 && padY <= 0) || FlxG.renderBlit) return;

		@:privateAccess
		for (other in FlxG.cameras.list)
		{
			if(other == camera || other == null || !other.exists || !other.visible) continue;
			if(other._fxFlashAlpha > 0) coverWith(camera, other._fxFlashColor, other._fxFlashAlpha);
			if(other._fxFadeAlpha > 0) coverWith(camera, other._fxFadeColor, other._fxFadeAlpha);
		}

		var pause:substates.PauseSubState = Std.downcast(FlxG.state.subState, substates.PauseSubState);
		if(pause != null && pause.background != null && pause.background.visible && pause.background.alpha > 0)
			coverWith(camera, FlxColor.BLACK, pause.background.alpha);
	}

	static function coverWith(camera:FlxCamera, color:FlxColor, amount:Float):Void
	{
		var alpha:Float = ((color.alpha <= 0) ? 1 : color.alpha / 255) * amount;
		if(alpha <= 0) return;

		// (on the camera's own pixels, the way flixel draws its fades: they're zoomed)
		var graphics = camera.canvas.graphics;
		var sideX:Float = padX / camera.scaleX;
		var sideY:Float = padY / camera.scaleY;
		var left:Float = camera.viewMarginLeft - 1;
		var top:Float = camera.viewMarginTop - 1;
		var width:Float = camera.viewWidth + 2;
		var height:Float = camera.viewHeight + 2;

		graphics.beginFill(color.rgb, alpha);
		if(sideX > 0)
		{
			graphics.drawRect(left, top, sideX + 1, height);
			graphics.drawRect(camera.viewMarginRight - sideX, top, sideX + 1, height);
		}
		if(sideY > 0)
		{
			graphics.drawRect(left + sideX + 1, top, width - (sideX + 1) * 2, sideY + 1);
			graphics.drawRect(left + sideX + 1, camera.viewMarginBottom - sideY, width - (sideX + 1) * 2, sideY + 1);
		}
		graphics.endFill();
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

	// ------------------------------------------------------------------------------------------
	// The sides of the other screens
	// ------------------------------------------------------------------------------------------

	// On every screen whose camera doesn't fill the window (the menus, made for 1280x720), the Widescreen option fills the bars
	// with the screen itself, zoomed, blurred and darker. The game is then drawn on a picture of the whole window with those
	// behind it, the way the Supersampling option draws it (backend.Supersampling), which is where these are used
	static var sideSteps:Array<BitmapData> = null; //the copy, then each one half the size of the one before
	static var sideViews:Array<Bitmap> = null; //(drawn through these: the graphics card only smooths and darkens what a Bitmap shows)
	static var sideMatrix:Matrix = new Matrix();
	static var sideWait:Float = 0;
	static final SIDE_DARKNESS:ColorTransform = new ColorTransform(0.45, 0.45, 0.45);

	/**
	 * If there are bars on the sides of the window (or above and under it) to fill with the screen, this frame.
	 */
	public static function sidesWanted():Bool
	{
		#if mobile
		if(true) return false; //(drawing the whole screen again for them is too much for a phone's graphics card: the bars stay black there)
		#end
		var game = FlxG.game;
		if(!ClientPrefs.data.wideScreen || game == null || (game.x < 0.5 && game.y < 0.5)) return false;
		if(menuCamera != null && FlxG.cameras.list.contains(menuCamera)) return false; //(a menu made for wider screens fills them)
		var camera:FlxCamera = wideCamera;
		return !(camera != null && FlxG.cameras.list.contains(camera) && (padX > 0 || padY > 0)); //(a song's own camera fills them)
	}

	/**
	 * Draws the filled bars on a picture of the whole window, before the game is drawn on it.
	 */
	public static function drawSidesOn(target:BitmapData, factor:Float):Void
	{
		if(sideViews == null) return;
		var last:Bitmap = sideViews[sideViews.length - 1];
		var small:BitmapData = last.bitmapData;
		var cover:Float = Math.max(target.width / small.width, target.height / small.height);
		sideMatrix.identity();
		sideMatrix.scale(cover, cover);
		sideMatrix.translate((target.width - small.width * cover) / 2, (target.height - small.height * cover) / 2);
		target.draw(last, sideMatrix, SIDE_DARKNESS, null, null, true);
	}

	/**
	 * Takes the blurred copy from the finished picture of the window (a few times a second is enough for something that blurred).
	 */
	public static function takeSidesFrom(source:BitmapData, factor:Float):Void
	{
		sideWait -= FlxG.elapsed;
		if(sideWait > 0 && sideSteps != null) return;
		sideWait = 1 / 30;

		if(sideSteps == null)
		{
			// (on the graphics card only, like the picture they're copied from: drawn from one to the other there)
			sideSteps = [];
			sideViews = [];
			var width:Int = 256;
			var height:Int = 144;
			while(width >= 32)
			{
				var step:BitmapData = new BitmapData(width, height, false, 0xFF000000);
				step.disposeImage();
				sideSteps.push(step);
				sideViews.push(new Bitmap(step, AUTO, true));
				width >>= 1;
				height >>= 1;
			}
		}

		// only the game, not the bars around it
		var game = FlxG.game;
		var shownWidth:Float = FlxG.width * FlxG.scaleMode.scale.x * game.scaleX * factor;
		var shownHeight:Float = FlxG.height * FlxG.scaleMode.scale.y * game.scaleY * factor;
		if(shownWidth <= 0 || shownHeight <= 0) return;

		var whole:Bitmap = new Bitmap(source, AUTO, true);
		sideMatrix.identity();
		sideMatrix.translate(-game.x * factor, -game.y * factor);
		sideMatrix.scale(sideSteps[0].width / shownWidth, sideSteps[0].height / shownHeight);
		sideSteps[0].draw(whole, sideMatrix, null, null, null, true);
		whole.bitmapData = null;

		// (halved each time, smoothed: blurrier than shrinking it at once, where most of the picture is skipped)
		for (i in 1...sideSteps.length)
		{
			sideMatrix.identity();
			sideMatrix.scale(0.5, 0.5);
			sideSteps[i].draw(sideViews[i - 1], sideMatrix, null, null, null, true);
		}
	}

	// ------------------------------------------------------------------------------------------
	// Menus made for wider screens
	// ------------------------------------------------------------------------------------------

	static var menuCamera:FlxCamera = null;

	/**
	 * For a menu made to fill wider screens, with the Widescreen option on: its camera covers the whole window, starting at the
	 * window's top left corner, and the menu places its things on the camera's width and height instead of FlxG's (what's
	 * anchored to the right goes to the window's right edge, backgrounds cover it all). Returns false with the option off.
	 */
	public static function widenMenu(camera:FlxCamera):Bool
	{
		if(!ClientPrefs.data.wideScreen || camera == null) return false;
		menuCamera = camera;
		fitMenuCamera();
		return true;
	}

	static function fitMenuCamera():Void
	{
		var camera:FlxCamera = menuCamera;
		if(camera == null || !FlxG.cameras.list.contains(camera) || FlxG.game == null) return;

		var scale = FlxG.scaleMode.scale;
		var left:Float = Math.min(0, Math.floor(-FlxG.game.x / scale.x));
		var top:Float = Math.min(0, Math.floor(-FlxG.game.y / scale.y));
		camera.setPosition(left, top);
		camera.setSize(Math.ceil(FlxG.width - left * 2), Math.ceil(FlxG.height - top * 2));
	}

	/**
	 * Makes a background at least as big as a camera (and `margin` more on each side), keeping its shape.
	 */
	public static function cover(sprite:FlxSprite, camera:FlxCamera, scale:Float, margin:Float = 0):Void
	{
		if(sprite.frameWidth <= 0 || sprite.frameHeight <= 0) return;
		var wanted:Float = Math.max(scale, Math.max((camera.width + margin * 2) / sprite.frameWidth, (camera.height + margin * 2) / sprite.frameHeight));
		sprite.scale.set(wanted, wanted);
		sprite.updateHitbox();
	}
}
