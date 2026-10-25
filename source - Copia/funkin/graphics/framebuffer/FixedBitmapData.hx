package funkin.graphics.framebuffer;

import openfl.display.BitmapData;

/**
 * V-Slice's image to draw the screen on, which fixes a problem of the library when drawing things that are on the game's window.
 * Here it's a regular image: scripts use it as the type of what they keep a copy of the screen in.
 */
class FixedBitmapData extends BitmapData
{
	/**
	 * @param useGPU 	Taken for compatibility, the image is always one that can be read and drawn on.
	 */
	public static function create(width:Int, height:Int, useGPU:Bool = true):FixedBitmapData
	{
		return new FixedBitmapData((width < 1) ? 1 : width, (height < 1) ? 1 : height, true, 0);
	}
}

/**
 * V-Slice's functions for images of what's on the screen.
 */
class BitmapDataUtil
{
	/**
	 * Draws what the cameras are showing on an image, one over the other.
	 */
	public static function drawCameraScreens(bitmap:BitmapData, cameras:Array<FlxCamera>):BitmapData
	{
		bitmap.fillRect(bitmap.rect, 0);
		for (camera in cameras)
			if(camera != null)
				drawCameraScreen(bitmap, camera, false, camera.filters != null && camera.filters.length > 0);
		return bitmap;
	}

	/**
	 * Draws what a camera is showing on an image.
	 *
	 * @param drawFlashSprite 	If the camera's filters are drawn as well.
	 */
	public static function drawCameraScreen(bitmap:BitmapData, camera:FlxCamera, clearBitmap:Bool = true, drawFlashSprite:Bool = false):BitmapData
	{
		if(clearBitmap) bitmap.fillRect(bitmap.rect, 0);

		try
		{
			@:privateAccess camera.render();
			bitmap.draw(drawFlashSprite ? camera.flashSprite : camera.canvas, new openfl.geom.Matrix(1, 0, 0, 1, camera.flashSprite.x, camera.flashSprite.y));
		}
		catch(e:Dynamic)
		{
			trace('Could not draw a camera on an image: $e');
		}
		return bitmap;
	}

	public static function applyFilter(bitmap:BitmapData, filter:openfl.filters.BitmapFilter):BitmapData
	{
		if(bitmap != null && filter != null && bitmap.readable) bitmap.applyFilter(bitmap, bitmap.rect, new openfl.geom.Point(), filter);
		return bitmap;
	}

	// Images can't change their size here, what's drawn on one of another size is cut or leaves the rest empty
	public static function resize(bitmap:BitmapData, width:Int, height:Int):Void {}

	public static function copy(source:BitmapData, destination:BitmapData):Void
	{
		if(source == null || destination == null) return;

		destination.fillRect(destination.rect, 0);
		destination.draw(source);
	}
}
